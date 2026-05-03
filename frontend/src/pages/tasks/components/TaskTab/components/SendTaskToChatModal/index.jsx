import React, { useEffect, useMemo, useState } from 'react';
import { Modal, Form, Select, Input, message } from 'antd';
import { getChatGroups, sendGroupMessage } from '../../../../../../axios/api/chat';
import { buildTaskChatPayload, encodeTaskChatMessage } from '../../../../../chat/utils/taskMessageCodec';
import { handleApiError } from '../../../../../../utils/errorHandler';

const { TextArea } = Input;

const SendTaskToChatModal = ({ open, onCancel, task }) => {
    const [form] = Form.useForm();
    const [groups, setGroups] = useState([]);
    const [loading, setLoading] = useState(false);
    const [sending, setSending] = useState(false);

    useEffect(() => {
        if (!open) return;
        setLoading(true);
        getChatGroups()
            .then((res) => setGroups(res.data.results || res.data || []))
            .catch((e) => handleApiError(e, 'Qruplar yüklənmədi'))
            .finally(() => setLoading(false));
    }, [open]);

    useEffect(() => {
        if (open) form.resetFields();
    }, [form, open, task?.id]);

    const options = useMemo(
        () => groups.map((g) => ({ value: g.id, label: g.name })),
        [groups],
    );

    const handleOk = async () => {
        if (!task) return;
        const values = await form.validateFields();
        const payload = buildTaskChatPayload(task, values.note || '');
        setSending(true);
        try {
            await sendGroupMessage({
                group: values.group,
                content: encodeTaskChatMessage(payload),
            });
            message.success('Tapşırıq chata göndərildi');
            onCancel?.();
        } catch (e) {
            handleApiError(e, 'Chata göndərilmədi');
        } finally {
            setSending(false);
        }
    };

    return (
        <Modal
            title="Tapşırığı chata göndər"
            open={open}
            onCancel={onCancel}
            onOk={handleOk}
            okText="Göndər"
            cancelText="Ləğv et"
            confirmLoading={sending}
            destroyOnClose
        >
            <Form form={form} layout="vertical">
                <Form.Item name="group" label="Qrup" rules={[{ required: true, message: 'Qrup seçin' }]}>
                    <Select
                        showSearch
                        loading={loading}
                        placeholder="Qrup seçin"
                        options={options}
                        optionFilterProp="label"
                    />
                </Form.Item>
                <Form.Item name="note" label="Qeyd">
                    <TextArea rows={3} maxLength={1000} showCount placeholder="İstəyə bağlı qeyd yazın..." />
                </Form.Item>
            </Form>
        </Modal>
    );
};

export default SendTaskToChatModal;
