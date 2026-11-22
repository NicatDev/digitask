import React, { useMemo, useState } from 'react';
import { Alert, Button, Modal, Segmented, Table, Tag, Typography } from 'antd';
import { coordsText, fmtDate } from './utils';
import styles from './style.module.scss';

const { Text } = Typography;

const FIELD_LABEL = { register_number: 'Qeydiyyat nömrəsi', phone_number: 'Telefon' };

const refName = (r) => (r ? r.name : '');

/** Fayldakı təklif ilə sistemdəki müştərini yan-yana göstərir */
const CompareModal = ({ row, onClose }) => {
    const matches = useMemo(() => (row?.matches || []).filter((m) => m.customer || m.customer_id), [row]);
    const [idx, setIdx] = useState(0);
    if (!row) return null;
    const m = matches[Math.min(idx, Math.max(matches.length - 1, 0))];
    const ex = m?.customer || null;
    const d = row.data || {};
    const raw = row.raw || {};

    const matchedFields = new Set();
    (m?.matched_on || []).forEach((x) => {
        matchedFields.add(`in:${x.incoming_field}`);
        matchedFields.add(`ex:${x.existing_field}`);
    });

    const rows = [
        { key: 'full_name', label: 'Ad Soyad', file: d.full_name ?? raw.full_name, sys: ex?.full_name },
        { key: 'register_number', label: 'Qeydiyyat nömrəsi', file: d.register_number ?? raw.register_number, sys: ex?.register_number },
        { key: 'phone_number', label: 'Telefon', file: d.phone_number ?? raw.phone_number, sys: ex?.phone_number },
        { key: 'region', label: 'Region', file: refName(d.region) || raw.region, sys: ex?.region },
        { key: 'equipment', label: 'Avadanlıq', file: refName(d.equipment) || raw.equipment, sys: ex?.equipment },
        { key: 'optic_box', label: 'Optik qutu', file: refName(d.optic_box) || raw.optic_box, sys: ex?.optic_box },
        { key: 'address', label: 'Ünvan', file: d.address ?? raw.address, sys: ex?.address },
        { key: 'coords', label: 'Koordinat', file: coordsText(d.lat, d.lng), sys: ex ? coordsText(ex.lat, ex.lng) : '' },
    ];

    const columns = [
        { title: 'Sahə', dataIndex: 'label', width: 150, render: (v) => <Text strong>{v}</Text> },
        {
            title: 'Fayldakı təklif',
            dataIndex: 'file',
            render: (v, r) => (
                <span className={matchedFields.has(`in:${r.key}`) ? styles.matchCell : undefined}>
                    {v === null || v === undefined || v === '' ? <Text type="secondary">—</Text> : String(v)}
                </span>
            ),
        },
        {
            title: 'Sistemdəki müştəri',
            dataIndex: 'sys',
            render: (v, r) => (
                <span className={matchedFields.has(`ex:${r.key}`) ? styles.matchCell : undefined}>
                    {v === null || v === undefined || v === '' ? <Text type="secondary">—</Text> : String(v)}
                </span>
            ),
        },
    ];

    return (
        <Modal
            open
            onCancel={onClose}
            title={`Müqayisə — fayldakı ${row.row_number}-ci sətir`}
            width={860}
            footer={<Button onClick={onClose}>Bağla</Button>}
        >
            {matches.length > 1 && (
                <div style={{ marginBottom: 12 }}>
                    <Text type="secondary">Bu sətirə {matches.length} müştəri uyğun gəlir: </Text>
                    <Segmented
                        value={idx}
                        onChange={setIdx}
                        options={matches.map((x, i) => ({ value: i, label: x.customer?.full_name || `#${x.customer_id}` }))}
                    />
                </div>
            )}

            {m?.matched_on?.length > 0 && (
                <Alert
                    type="info"
                    showIcon
                    style={{ marginBottom: 12 }}
                    title={
                        <>
                            Uyğun gəlir:{' '}
                            {m.matched_on.map((x, i) => (
                                <Tag key={i} color="blue">
                                    fayldakı {FIELD_LABEL[x.incoming_field] || x.incoming_field} = sistemdəki{' '}
                                    {FIELD_LABEL[x.existing_field] || x.existing_field}
                                </Tag>
                            ))}
                        </>
                    }
                />
            )}
            {m?.same_name && (
                <Alert type="warning" showIcon style={{ marginBottom: 12 }}
                       title="Bu müştərinin yalnız adı eynidir, nömrələri fərqlidir. Eyni adam olub-olmadığını yoxlayın." />
            )}
            {!ex && (
                <Alert type="warning" showIcon style={{ marginBottom: 12 }}
                       title="Sistemdəki müştəri artıq silinib və ya məlumatı tapılmadı." />
            )}

            <Table size="small" rowKey="key" columns={columns} dataSource={rows} pagination={false} bordered />

            {ex && (
                <div style={{ marginTop: 10, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                    <Tag>Sistem ID: {ex.id}</Tag>
                    <Tag color={ex.is_active ? 'green' : 'default'}>{ex.is_active ? 'Aktiv' : 'Deaktiv (silinib)'}</Tag>
                    <Tag>Yaradılıb: {fmtDate(ex.created_at)}</Tag>
                    {ex.has_passport_image && <Tag color="purple">Passport şəkli var</Tag>}
                    <Text type="secondary" style={{ fontSize: 12 }}>Məlumat import anındakı vəziyyətdir.</Text>
                </div>
            )}
        </Modal>
    );
};

export default CompareModal;
