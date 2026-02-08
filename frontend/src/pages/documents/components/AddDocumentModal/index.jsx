import React, { useState } from 'react';
import { Modal, Form, Input, Upload, Button, message } from 'antd';
import { UploadOutlined, FileAddOutlined } from '@ant-design/icons';
import { createTaskDocument } from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';
import styles from './style.module.scss';

const AddDocumentModal = ({ open, onClose, onSuccess }) => {
    const [form] = Form.useForm();
    const [loading, setLoading] = useState(false);
    const [fileList, setFileList] = useState([]);

    const handleSubmit = async () => {
        try {
            const values = await form.validateFields();

            if (fileList.length === 0) {
                message.error('Fayl seçin');
                return;
            }

            setLoading(true);

            const data = {
                title: values.title,
                action: values.action || '',
                file: fileList[0].originFileObj
            };

            await createTaskDocument(data);
            message.success('Sənəd uğurla əlavə edildi');
            form.resetFields();
            setFileList([]);
            onSuccess?.();
            onClose();
        } catch (error) {
            if (error.errorFields) {
                // Form validation error
                return;
            }
            handleApiError(error, 'Sənəd əlavə edilə bilmədi');
        } finally {
            setLoading(false);
        }
    };

    const handleCancel = () => {
        form.resetFields();
        setFileList([]);
        onClose();
    };

    const uploadProps = {
        beforeUpload: (file) => {
            // Store file with originFileObj structure for compatibility
            setFileList([{
                uid: file.uid || '-1',
                name: file.name,
                status: 'done',
                originFileObj: file
            }]);
            return false; // Prevent auto upload
        },
        onRemove: () => {
            setFileList([]);
        },
        fileList,
        maxCount: 1
    };

    return (
        <Modal
            title={
                <div className={styles.modalTitle}>
                    <FileAddOutlined />
                    <span>Yeni Sənəd Əlavə Et</span>
                </div>
            }
            open={open}
            onCancel={handleCancel}
            onOk={handleSubmit}
            confirmLoading={loading}
            okText="Əlavə et"
            cancelText="İmtina"
            width={500}
            destroyOnClose
        >
            <Form
                form={form}
                layout="vertical"
                className={styles.form}
            >
                <Form.Item
                    name="title"
                    label="Başlıq"
                    rules={[{ required: true, message: 'Başlıq daxil edin' }]}
                >
                    <Input placeholder="Sənədin başlığını daxil edin" />
                </Form.Item>

                <Form.Item
                    name="action"
                    label="Proses / Əməliyyat"
                >
                    <Input.TextArea
                        placeholder="Prosesin açıqlaması (məs: Anbar daxilolma, Satış qəbzi və s.)"
                        rows={3}
                    />
                </Form.Item>

                <Form.Item
                    label="Fayl"
                    required
                >
                    <Upload {...uploadProps} className={styles.upload}>
                        <Button icon={<UploadOutlined />} block>
                            {fileList.length > 0 ? fileList[0].name : 'Fayl seçin'}
                        </Button>
                    </Upload>
                </Form.Item>
            </Form>
        </Modal>
    );
};

export default AddDocumentModal;
