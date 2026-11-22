import React, { useEffect, useState } from 'react';
import { Alert, Button, Checkbox, List, Modal, Spin, Typography } from 'antd';
import { getCustomerImportRollbackCheck, rollbackCustomerImport } from '../../../../axios/api/tasks';
import { REF_LABELS, showError } from './utils';

const { Paragraph, Text } = Typography;

/** Geri qaytarmadan əvvəl nə silinəcəyini göstərir və açıq təsdiq istəyir */
const RollbackModal = ({ batch, onClose, onDone }) => {
    const [check, setCheck] = useState(null);
    const [loading, setLoading] = useState(true);
    const [agree, setAgree] = useState(false);
    const [submitting, setSubmitting] = useState(false);

    useEffect(() => {
        let alive = true;
        getCustomerImportRollbackCheck(batch.id)
            .then((res) => alive && setCheck(res.data))
            .catch((e) => showError(e, 'Yoxlama alınmadı'))
            .finally(() => alive && setLoading(false));
        return () => { alive = false; };
    }, [batch.id]);

    const submit = async () => {
        setSubmitting(true);
        try {
            const res = await rollbackCustomerImport(batch.id);
            onDone?.(res.data);
            onClose();
        } catch (e) {
            await showError(e, 'Geri qaytarma başlamadı');
        } finally {
            setSubmitting(false);
        }
    };

    const refs = Object.entries(check?.refs || {}).filter(([, v]) => v?.length);

    return (
        <Modal
            open
            title="Importu geri qaytar"
            onCancel={onClose}
            width={640}
            footer={[
                <Button key="c" onClick={onClose}>İmtina</Button>,
                <Button
                    key="ok"
                    danger
                    type="primary"
                    loading={submitting}
                    disabled={!check?.can_proceed || !agree}
                    onClick={submit}
                >
                    Geri qaytar
                </Button>,
            ]}
        >
            {loading ? (
                <div style={{ textAlign: 'center', padding: 24 }}><Spin /></div>
            ) : !check ? null : (
                <>
                    <Paragraph>
                        Bu əməliyyat sistemi <b>bu importdan əvvəlki vəziyyətə</b> qaytarır: yalnız bu importla yaradılmış
                        müştərilər silinir. Sistemdə əvvəldən olan müştərilərə toxunulmur.
                    </Paragraph>

                    {!check.allowed && <Alert type="error" showIcon title={check.reason || 'Bu importu geri qaytarmaq olmur.'} style={{ marginBottom: 12 }} />}

                    <Alert
                        type="warning"
                        showIcon
                        style={{ marginBottom: 12 }}
                        title={<><b>{check.customers_to_delete}</b> müştəri silinəcək</>}
                        description={
                            <>
                                {check.with_passport_image > 0 && (
                                    <div>Onlardan {check.with_passport_image}-nin sonradan əlavə edilmiş passport şəkli var — şəkillər də silinəcək.</div>
                                )}
                                {refs.map(([kind, list]) => (
                                    <div key={kind}>
                                        Bu importla yaradılmış {REF_LABELS[kind].toLowerCase()}: {list.map((x) => x.name).join(', ')}
                                        <Text type="secondary"> (başqa yerdə istifadə olunmursa silinəcək)</Text>
                                    </div>
                                ))}
                            </>
                        }
                    />

                    {(check.blocked?.length > 0 || check.blocked_other?.length > 0) && (
                        <Alert
                            type="error"
                            showIcon
                            style={{ marginBottom: 12 }}
                            title="Geri qaytarmaq olmur"
                            description={
                                <>
                                    <div>
                                        Bu importla yaradılmış {check.blocked_total || check.blocked.length} müştəriyə artıq tapşırıq verilib.
                                        Onları silmək tapşırıq məlumatlarını da itirərdi.
                                    </div>
                                    {check.blocked?.length > 0 && (
                                        <List
                                            size="small"
                                            style={{ maxHeight: 180, overflow: 'auto', marginTop: 8 }}
                                            dataSource={check.blocked}
                                            renderItem={(c) => (
                                                <List.Item>{c.full_name} {c.register_number ? `(${c.register_number})` : ''} — {c.reason}</List.Item>
                                            )}
                                        />
                                    )}
                                    {check.blocked_other?.map((x) => <div key={x}>{x}</div>)}
                                </>
                            }
                        />
                    )}

                    {check.can_proceed && (
                        <Checkbox checked={agree} onChange={(e) => setAgree(e.target.checked)}>
                            Başa düşürəm: {check.customers_to_delete} müştəri silinəcək və bu geri qaytarılmır.
                        </Checkbox>
                    )}
                </>
            )}
        </Modal>
    );
};

export default RollbackModal;
