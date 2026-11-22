import React, { useCallback, useEffect, useState } from 'react';
import { Button, Input, Space, Table, Tag, Tooltip, Typography } from 'antd';
import { DownloadOutlined, SwapOutlined, WarningOutlined } from '@ant-design/icons';
import { getCustomerImportRows } from '../../../../axios/api/tasks';
import CompareModal from './CompareModal';
import { RESULT_META, downloadFile, showError } from './utils';
import styles from './style.module.scss';

const { Text } = Typography;

const refCell = (ref, raw) => {
    if (!ref) return raw ? <Text type="secondary">{String(raw)}</Text> : <Text type="secondary">—</Text>;
    return (
        <Space size={4} wrap>
            <span>{ref.name}</span>
            {ref.action === 'create' && <Tag color="orange" style={{ marginInlineEnd: 0 }}>yeni</Tag>}
            {ref.action === 'match' && ref.score < 1 && (
                <Tooltip title={`Fayldakı: «${ref.input}» — oxşarlıq ${Math.round(ref.score * 100)}%`}>
                    <Tag color="gold" style={{ marginInlineEnd: 0 }}>oxşar</Tag>
                </Tooltip>
            )}
        </Space>
    );
};

/** Bir tab üçün sətirlər (serverdən səhifə-səhifə) */
const RowsTable = ({ batchId, group, refreshKey }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);
    const [page, setPage] = useState(1);
    const [pageSize, setPageSize] = useState(50);
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

    /** Təmizlənmiş dəyər; problemli sətirdə isə səhvi görmək üçün fayldakı orijinal dəyər (boz) */
    const valueCell = (r, field) => {
        const clean = r.data?.[field];
        if (clean) return clean;
        const raw = r.raw?.[field];
        if (r.result === 'problem' && raw !== null && raw !== undefined && String(raw).trim() !== '') {
            return <Text type="secondary">{String(raw)}</Text>;
        }
        return <Text type="secondary">—</Text>;
    };
    const refOrRaw = (r, field) => refCell(r.data?.[field], r.result === 'problem' ? r.raw?.[field] : null);

    const columns = [
        { title: 'Sətir', dataIndex: 'row_number', width: 70, fixed: 'left' },
        { title: 'Ad Soyad', width: 200, render: (_, r) => valueCell(r, 'full_name') },
        { title: 'Qeydiyyat №', width: 130, render: (_, r) => valueCell(r, 'register_number') },
        { title: 'Telefon', width: 150, render: (_, r) => valueCell(r, 'phone_number') },
        { title: 'Region', width: 160, render: (_, r) => refOrRaw(r, 'region') },
        { title: 'Avadanlıq', width: 170, render: (_, r) => refOrRaw(r, 'equipment') },
        {
            title: 'Nəticə',
            width: 120,
            render: (_, r) => {
                const meta = RESULT_META[r.result] || { color: 'default', label: r.result };
                return (
                    <Space orientation="vertical" size={2}>
                        <Tag color={meta.color} style={{ marginInlineEnd: 0 }}>{meta.label}</Tag>
                        {r.created_customer && <Text type="secondary" style={{ fontSize: 11 }}>ID {r.created_customer}</Text>}
                        {r.result === 'created' && !r.created_customer && (
                            <Text type="secondary" style={{ fontSize: 11 }}>sonradan silinib</Text>
                        )}
                    </Space>
                );
            },
        },
        {
            title: 'Səbəb / qeyd',
            render: (_, r) => (
                <div className={styles.reasons}>
                    {(r.reasons || []).filter((x) => x.code !== 'exists').map((x, i) => (
                        <div key={`r${i}`} className={r.result === 'problem' ? styles.reasonError : undefined}>• {x.message}</div>
                    ))}
                    {(r.warnings || []).map((x, i) => (
                        <div key={`w${i}`} className={styles.reasonWarn}><WarningOutlined /> {x.message}</div>
                    ))}
                    {r.result === 'existing' && (r.reasons || []).some((x) => x.code === 'exists') && (
                        <div>Bu nömrə ilə müştəri sistemdə artıq var.</div>
                    )}
                </div>
            ),
        },
        {
            title: '',
            width: 120,
            fixed: 'right',
            render: (_, r) =>
                (r.matches || []).length > 0 ? (
                    <Button size="small" icon={<SwapOutlined />} onClick={() => setCompareRow(r)}>
                        Müqayisə et
                    </Button>
                ) : null,
        },
    ];

    return (
        <>
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
            <Table
                size="small"
                rowKey="id"
                loading={loading}
                columns={columns}
                dataSource={data}
                scroll={{ x: 1200 }}
                pagination={{
                    current: page,
                    pageSize,
                    total,
                    showSizeChanger: true,
                    pageSizeOptions: ['20', '50', '100', '200'],
                    showTotal: (t) => `Cəmi ${t}`,
                    onChange: (p, s) => { setPage(p); setPageSize(s); },
                }}
            />
            {compareRow && <CompareModal row={compareRow} onClose={() => setCompareRow(null)} />}
        </>
    );
};

export default RowsTable;
