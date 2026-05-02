import React, { useState } from 'react';
import { Modal, Typography, Button, Divider, Empty } from 'antd';
import {
    TASK_TABLE_COLUMN_META,
    TASK_TABLE_FIXED_KEYS,
} from '../../taskTableColumnPrefs';

const TaskColumnSettingsModal = ({ open, onCancel, onConfirm, initialVisibility }) => {
    const [draft, setDraft] = useState(() => ({ ...initialVisibility }));

    const toggleable = TASK_TABLE_COLUMN_META.filter((c) => !TASK_TABLE_FIXED_KEYS.has(c.key));

    const hidden = toggleable.filter((c) => !draft[c.key]);
    const visible = toggleable.filter((c) => draft[c.key]);

    const setKey = (key, value) => {
        setDraft((d) => ({ ...d, [key]: value }));
    };

    return (
        <Modal
            title="Cədvəl sütunları"
            open={open}
            onCancel={onCancel}
            onOk={() => onConfirm(draft)}
            okText="Yadda saxla"
            cancelText="Ləğv et"
            width={480}
            destroyOnHidden
        >
            <Typography.Paragraph type="secondary" style={{ marginBottom: 16 }}>
                Sütunların sırası dəyişmir. Yalnız hansının göstəriləcəyini seçirsiniz. Ayarlar profil
                məlumatınızda (verilənlər bazasında) saxlanılır.
            </Typography.Paragraph>

            <Typography.Text strong>Görünməyən sütunlar</Typography.Text>
            <div style={{ marginTop: 8, marginBottom: 8, minHeight: 48 }}>
                {hidden.length === 0 ? (
                    <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="Hamısı göstərilir" />
                ) : (
                    <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
                        {hidden.map((col) => (
                            <li
                                key={col.key}
                                style={{
                                    display: 'flex',
                                    justifyContent: 'space-between',
                                    alignItems: 'center',
                                    padding: '6px 0',
                                    borderBottom: '1px solid #f5f5f5',
                                }}
                            >
                                <span>{col.title}</span>
                                <Button type="link" size="small" onClick={() => setKey(col.key, true)}>
                                    Göstər
                                </Button>
                            </li>
                        ))}
                    </ul>
                )}
            </div>

            <Divider style={{ margin: '12px 0' }} />

            <Typography.Text strong>Göstərilən sütunlar</Typography.Text>
            <div style={{ marginTop: 8, minHeight: 48 }}>
                {visible.length === 0 ? (
                    <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description="Ən azı bir sütun seçin" />
                ) : (
                    <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
                        {visible.map((col) => (
                            <li
                                key={col.key}
                                style={{
                                    display: 'flex',
                                    justifyContent: 'space-between',
                                    alignItems: 'center',
                                    padding: '6px 0',
                                    borderBottom: '1px solid #f5f5f5',
                                }}
                            >
                                <span>{col.title}</span>
                                <Button type="link" size="small" danger onClick={() => setKey(col.key, false)}>
                                    Gizlət
                                </Button>
                            </li>
                        ))}
                    </ul>
                )}
            </div>

            <Typography.Paragraph type="secondary" style={{ marginTop: 16, marginBottom: 0, fontSize: 12 }}>
                «Əməliyyat» sütunu həmişə görünür.
            </Typography.Paragraph>
        </Modal>
    );
};

export default TaskColumnSettingsModal;
