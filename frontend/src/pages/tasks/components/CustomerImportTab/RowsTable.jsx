import React, { useCallback, useEffect, useState } from 'react';
import { Alert, Button, Empty, Input, List, Space, Tag, Tooltip, Typography } from 'antd';
import {
    CheckCircleFilled, CloseCircleFilled, CopyOutlined, DownloadOutlined, InfoCircleFilled,
    SwapOutlined, WarningFilled,
} from '@ant-design/icons';
import { getCustomerImportRows } from '../../../../axios/api/tasks';
import CompareModal from './CompareModal';
import { RESULT_META, coordsText, downloadFile, showError } from './utils';
import styles from './style.module.scss';

const { Text } = Typography;

const FIELD_AZ = { register_number: 'qeydiyyat nömrəsi', phone_number: 'telefonu' };

/** "N:554264644" → "0554264644" */
const keyToNumber = (key) => {
    if (!key) return '';
    const v = key.slice(2);
    return key.startsWith('N:') && v.length === 9 ? `0${v}` : v;
};

const isEmpty = (v) => v === null || v === undefined || String(v).trim() === '';

const GROUP_HINT = {
    new: (preview) => ({
        type: 'success',
        text: preview
            ? 'Bu müştərilər “Təsdiqlə” düyməsindən sonra yaradılacaq.'
            : 'Bu müştərilər import zamanı yaradılıb.',
    }),
    existing: () => ({
        type: 'info',
        text: 'Bu sətirlər sistemdə artıq olduğu üçün yaradılmır və sistemdəki müştəri dəyişdirilmir. '
            + '“Müqayisə et” ilə fayldakı məlumatı sistemdəki ilə yan-yana görə bilərsiniz.',
    }),
    problem: () => ({
        type: 'error',
        text: 'Bu sətirlər yaradılmayacaq. Hər sətrin altında qırmızı xanada səbəbi yazılıb. '
            + 'Düzəltmək üçün: “Excel kimi endir” → səbəbə görə düzəldin → faylı yenidən yükləyin. '
            + 'Artıq yaradılmış müştərilər təkrar yaradılmayacaq.',
    }),
};

/** Region / avadanlıq / optik qutu dəyəri + "yeni" / "oxşar" nişanı */
const RefValue = ({ refData, raw, showRaw, willCreate }) => {
    if (!refData) {
        return showRaw && !isEmpty(raw) ? <Text type="danger">{String(raw)}</Text> : <Text type="secondary">—</Text>;
    }
    return (
        <span className={styles.refValue}>
            {refData.action === 'create' && !willCreate ? refData.input : refData.name}
            {refData.action === 'create' && willCreate && <Tag color="orange">yeni yaradılacaq</Tag>}
            {refData.action === 'match' && refData.score < 1 && (
                <Tooltip title={`Faylda «${refData.input}» yazılıb — ${Math.round(refData.score * 100)}% oxşarlıqla tapıldı`}>
                    <Tag color="gold">oxşar ad</Tag>
                </Tooltip>
            )}
        </span>
    );
};

const Field = ({ label, children }) => (
    <div className={styles.field}>
        <span className={styles.fieldLabel}>{label}</span>
        <span className={styles.fieldValue}>{children}</span>
    </div>
);

/** Sistemdə artıq var: hansı nömrə kimə aiddir — sadə cümlə ilə */
const ExistingExplain = ({ row }) => {
    const m = (row.matches || []).find((x) => (x.matched_on || []).length);
    if (!m) return <>Bu nömrə ilə müştəri sistemdə artıq var.</>;
    const on = m.matched_on[0];
    const who = m.customer?.full_name ? `«${m.customer.full_name}»` : `#${m.customer_id}`;
    const inactive = m.customer && m.customer.is_active === false ? ' (bu müştəri silinib/deaktivdir)' : '';
    return (
        <>
            Fayldakı {on.incoming_field === 'register_number' ? 'qeydiyyat nömrəsi' : 'telefon'}{' '}
            <b>{keyToNumber(on.key)}</b> sistemdəki {who} müştərisinin {FIELD_AZ[on.existing_field] || on.existing_field} ilə eynidir{inactive}.
            {row.matches.length > 1 && ` Bu nömrə ilə ${row.matches.length} müştəri var.`}
        </>
    );
};

const RowCard = ({ row, onCompare }) => {
    const meta = RESULT_META[row.result] || { color: 'default', label: row.result };
    const d = row.data || {};
    const raw = row.raw || {};
    const isProblem = row.result === 'problem';
    const willCreate = row.result === 'new';
    const val = (field) => {
        if (!isEmpty(d[field])) return d[field];
        if (isProblem && !isEmpty(raw[field])) return <Text type="danger">{String(raw[field])}</Text>;
        return <Text type="secondary">—</Text>;
    };
    const coords = d.lat !== null && d.lat !== undefined
        ? coordsText(d.lat, d.lng)
        : (isProblem && (!isEmpty(raw.lat) || !isEmpty(raw.lng))
            ? <Text type="danger">{`${raw.lat ?? '—'}, ${raw.lng ?? '—'}`}</Text>
            : <Text type="secondary">—</Text>);

    const reasons = (row.reasons || []).filter((x) => !['exists', 'exists_after_preview', 'duplicate_in_file'].includes(x.code));
    // Yaradılmayacaq sətirdə "yeni region yaradılacaq" kimi qeydlər çaşdırıcıdır — göstərmirik
    const warnings = (row.warnings || []).filter((w) => row.result === 'new' || row.result === 'created' || !w.code.endsWith('_create'));
    const lateExisting = (row.reasons || []).find((x) => x.code === 'exists_after_preview');
    const hasMatches = (row.matches || []).length > 0;

    return (
        <div className={`${styles.rowCard} ${styles[`rowCard_${row.result}`] || ''}`}>
            <div className={styles.rowHead}>
                <div className={styles.rowTitle}>
                    <span className={styles.rowNum}>Sətir {row.row_number}</span>
                    <span className={styles.rowName}>{isEmpty(d.full_name) ? val('full_name') : d.full_name}</span>
                </div>
                <Space size={8} wrap>
                    <Tag color={meta.color} className={styles.resultTag}>{meta.label}</Tag>
                    {row.created_customer && <Text type="secondary">Sistem ID: {row.created_customer}</Text>}
                    {row.result === 'created' && !row.created_customer && <Text type="secondary">sonradan silinib</Text>}
                    {hasMatches && (
                        <Button size="small" icon={<SwapOutlined />} onClick={() => onCompare(row)}>
                            Müqayisə et
                        </Button>
                    )}
                </Space>
            </div>

            <div className={styles.fieldsGrid}>
                <Field label="Qeydiyyat №">{val('register_number')}</Field>
                <Field label="Telefon">{val('phone_number')}</Field>
                <Field label="Region"><RefValue refData={d.region} raw={raw.region} showRaw={isProblem} willCreate={willCreate} /></Field>
                <Field label="Avadanlıq"><RefValue refData={d.equipment} raw={raw.equipment} showRaw={isProblem} willCreate={willCreate} /></Field>
                <Field label="Optik qutu"><RefValue refData={d.optic_box} raw={raw.optic_box} showRaw={isProblem} willCreate={willCreate} /></Field>
                <Field label="Ünvan">{val('address')}</Field>
                <Field label="Koordinat">{coords}</Field>
            </div>

            {isProblem && reasons.length > 0 && (
                <div className={`${styles.note} ${styles.noteError}`}>
                    <div className={styles.noteTitle}><CloseCircleFilled /> Niyə yaradılmayacaq?</div>
                    <ul>{reasons.map((x, i) => <li key={i}>{x.message}</li>)}</ul>
                </div>
            )}
            {row.result === 'existing' && (
                <div className={`${styles.note} ${styles.noteInfo}`}>
                    <div className={styles.noteTitle}><InfoCircleFilled /> Sistemdə artıq var — yaradılmayacaq</div>
                    <div>
                        {lateExisting ? `${lateExisting.message} ` : null}
                        <ExistingExplain row={row} />
                    </div>
                </div>
            )}
            {row.result === 'duplicate_in_file' && (
                <div className={`${styles.note} ${styles.noteInfo}`}>
                    <div className={styles.noteTitle}><CopyOutlined /> Faylda təkrar</div>
                    <div>Faylın {row.duplicate_of_row}-ci sətri ilə tam eynidir — müştəri yalnız bir dəfə yaradılır.</div>
                </div>
            )}
            {warnings.length > 0 && (
                <div className={`${styles.note} ${styles.noteWarn}`}>
                    <div className={styles.noteTitle}><WarningFilled /> Diqqət</div>
                    <ul>{warnings.map((x, i) => <li key={i}>{x.message}</li>)}</ul>
                </div>
            )}
            {(row.result === 'new' || row.result === 'created') && warnings.length === 0 && (
                <div className={styles.okLine}><CheckCircleFilled /> Problem yoxdur</div>
            )}
        </div>
    );
};

/** Bir tab üçün sətirlər (serverdən səhifə-səhifə) */
const RowsTable = ({ batchId, group, refreshKey, isPreview }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);
    const [page, setPage] = useState(1);
    const [pageSize, setPageSize] = useState(20);
    const [total, setTotal] = useState(0);
    const [search, setSearch] = useState('');
    const [query, setQuery] = useState('');
    const [compareRow, setCompareRow] = useState(null);

    const load = useCallback(async () => {
        if (!batchId) return;
        setLoading(true);
        try {
            const res = await getCustomerImportRows(batchId, { group, page, page_size: pageSize, search: query || undefined });
            setData(res.data.results || []);
            setTotal(res.data.count || 0);
        } catch (e) {
            await showError(e, 'Sətirlər yüklənmədi');
        } finally {
            setLoading(false);
        }
    }, [batchId, group, page, pageSize, query]);

    useEffect(() => { load(); }, [load, refreshKey]);
    useEffect(() => { setPage(1); }, [query, group, batchId]);
    useEffect(() => {
        const t = setTimeout(() => setQuery(search.trim()), 400);
        return () => clearTimeout(t);
    }, [search]);

    const hint = GROUP_HINT[group]?.(isPreview);

    return (
        <>
            {hint && total > 0 && <Alert type={hint.type} showIcon title={hint.text} className={styles.groupHint} />}
            <div className={styles.rowsToolbar}>
                <Input.Search
                    allowClear
                    placeholder="Ad, nömrə və ya sətir nömrəsi ilə axtar"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    style={{ maxWidth: 360 }}
                />
                <Button
                    icon={<DownloadOutlined />}
                    disabled={!total}
                    onClick={() => downloadFile(`${batchId}/rows/export/`, { group, search: query || undefined }, `import-${group}.xlsx`)}
                >
                    Excel kimi endir
                </Button>
            </div>
            <List
                loading={loading}
                dataSource={data}
                locale={{ emptyText: <Empty description={query ? 'Axtarışa uyğun sətir yoxdur' : 'Bu bölmədə sətir yoxdur'} /> }}
                renderItem={(row) => <RowCard key={row.id} row={row} onCompare={setCompareRow} />}
                pagination={total > pageSize ? {
                    current: page,
                    pageSize,
                    total,
                    showSizeChanger: true,
                    pageSizeOptions: ['20', '50', '100'],
                    showTotal: (t) => `Cəmi ${t}`,
                    onChange: (p, s) => { setPage(p); setPageSize(s); },
                    align: 'center',
                } : false}
            />
            {compareRow && <CompareModal row={compareRow} onClose={() => setCompareRow(null)} />}
        </>
    );
};

export default RowsTable;
