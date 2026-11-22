import React, { useState } from 'react';
import { Alert, Descriptions, Drawer, Tabs, Tag } from 'antd';
import RowsTable from './RowsTable';
import { REF_LABELS, STATUS_META, fmtDate, fmtSize } from './utils';

/** Bir importun detalları: Yeni / Artıq var / Problemli tabları */
const BatchDetailDrawer = ({ batch, onClose, refreshKey }) => {
    const [tab, setTab] = useState('new');
    if (!batch) return null;
    const st = STATUS_META[batch.status] || { color: 'default', label: batch.status_label };
    const isPreview = batch.status === 'preview';
    const newCount = isPreview ? batch.new_count : batch.created_count + (batch.status === 'interrupted' ? batch.new_count : 0);
    const rb = batch.rollback_summary || {};

    const items = [
        {
            key: 'new',
            label: `${isPreview ? 'Yaradılacaq' : 'Yeni əlavə olunanlar'} (${newCount})`,
            children: <RowsTable batchId={batch.id} group="new" refreshKey={refreshKey} />,
        },
        {
            key: 'existing',
            label: `Artıq var (${batch.existing_count + batch.duplicate_in_file_count})`,
            children: <RowsTable batchId={batch.id} group="existing" refreshKey={refreshKey} />,
        },
        {
            key: 'problem',
            label: `Problemli (${batch.problem_count})`,
            children: <RowsTable batchId={batch.id} group="problem" refreshKey={refreshKey} />,
        },
    ];

    return (
        <Drawer open onClose={onClose} size="min(1280px, 100vw)" title={`Import: ${batch.original_filename}`} destroyOnHidden>
            <Descriptions size="small" bordered column={{ xs: 1, sm: 2, lg: 3 }} style={{ marginBottom: 16 }}>
                <Descriptions.Item label="Status"><Tag color={st.color}>{st.label}</Tag></Descriptions.Item>
                <Descriptions.Item label="Fayl">{batch.source_type === 'excel' ? 'Excel' : 'JSON'} · {fmtSize(batch.file_size)}</Descriptions.Item>
                <Descriptions.Item label="Cəmi sətir">{batch.total_rows}</Descriptions.Item>
                <Descriptions.Item label="Yükləyib">{batch.created_by_name || '—'} · {fmtDate(batch.created_at)}</Descriptions.Item>
                <Descriptions.Item label="Təsdiqləyib">{batch.confirmed_by_name ? `${batch.confirmed_by_name} · ${fmtDate(batch.confirmed_at)}` : '—'}</Descriptions.Item>
                <Descriptions.Item label="Bitib">{fmtDate(batch.finished_at)}</Descriptions.Item>
                {batch.status === 'rolled_back' && (
                    <Descriptions.Item label="Geri qaytarılıb" span={3}>
                        {batch.rolled_back_by_name || '—'} · {fmtDate(batch.rolled_back_at)} · {rb.deleted_customers ?? 0} müştəri silindi
                        {rb.deleted_images ? `, ${rb.deleted_images} şəkil` : ''}
                    </Descriptions.Item>
                )}
            </Descriptions>

            {batch.status === 'rolled_back' && (
                <Alert type="info" showIcon style={{ marginBottom: 12 }}
                       title="Bu import geri qaytarılıb. Aşağıdakı siyahı tarixçə üçün saxlanılıb — həmin müştərilər artıq sistemdə yoxdur." />
            )}
            {batch.error_message && batch.status !== 'rolled_back' && (
                <Alert type="error" showIcon style={{ marginBottom: 12 }} title={batch.error_message} />
            )}
            {Object.entries(batch.created_refs || {}).some(([, v]) => v?.length) && batch.status !== 'rolled_back' && (
                <Alert
                    type="info"
                    showIcon
                    style={{ marginBottom: 12 }}
                    title="Bu importla yaradılan siyahı elementləri"
                    description={Object.entries(batch.created_refs).filter(([, v]) => v?.length)
                        .map(([k, v]) => <div key={k}>{REF_LABELS[k]}: {v.length} ədəd</div>)}
                />
            )}

            <Tabs activeKey={tab} onChange={setTab} items={items} destroyOnHidden />
        </Drawer>
    );
};

export default BatchDetailDrawer;
