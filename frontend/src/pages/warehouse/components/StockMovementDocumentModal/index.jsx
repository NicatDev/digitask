import React, { useState, useEffect } from 'react';
import { Modal, Form, Input, Upload, Table, Button, message } from 'antd';
import { UploadOutlined, DeleteOutlined, FileOutlined } from '@ant-design/icons';
import { createTaskDocument, deleteTaskDocument, getTaskDocuments } from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';

const StockMovementDocumentModal = ({ open, onCancel, stockMovement, onSuccess }) => {
    const [form] = Form.useForm();
    const [documents, setDocuments] = useState([]);
    const [submitting, setSubmitting] = useState(false);
    const [fileList, setFileList] = useState([]);
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        if (open && stockMovement?.id) {
            fetchDocuments();
        } else {
            form.resetFields();
            setFileList([]);
            setDocuments([]);
        }
    }, [open, stockMovement]);

    const fetchDocuments = async () => {
        setLoading(true);
        try {
            const res = await getTaskDocuments({ stock_movement: stockMovement.id });
            setDocuments(res.data.results || res.data);
        } catch (error) {
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const handleSubmit = async (values) => {
        if (fileList.length === 0) {
            message.error('Fayl seçin');
            return;
        }

        setSubmitting(true);
        try {
            await createTaskDocument({
                title: values.title,
                file: fileList[0].originFileObj,
                stock_movement: stockMovement?.id
            });
            message.success('Sənəd əlavə olundu');
            form.resetFields();
            setFileList([]);
            fetchDocuments();
            onSuccess?.();
        } catch (error) {
            handleApiError(error, 'Sənəd əlavə olunmadı');
        } finally {
            setSubmitting(false);
        }
    };

    const handleDelete = async (id) => {
        try {
            await deleteTaskDocument(id);
            message.success('Sənəd silindi');
            setDocuments(documents.filter(d => d.id !== id));
            onSuccess?.();
        } catch (error) {
            handleApiError(error, 'Sənəd silinmədi');
        }
    };

    const columns = [
        {
            title: 'Fayl',
            dataIndex: 'file_url',
            key: 'file_url',
            render: (url) => url ? (
                <a href={url} target="_blank" rel="noopener noreferrer">
                    <FileOutlined style={{ fontSize: 24, color: '#1890ff' }} />
                </a>
            ) : '-'
        },
        { title: 'Başlıq', dataIndex: 'title', key: 'title' },
        {
            title: 'Tarix',
            dataIndex: 'created_at',
            key: 'created_at',
            render: (date) => new Date(date).toLocaleDateString('az-AZ')
        },
        {
            title: '',
            key: 'action',
            render: (_, record) => (
                <Button
                    type="text"
                    danger
                    icon={<DeleteOutlined />}
                    onClick={() => handleDelete(record.id)}
                />
            )
        }
    ];

    const uploadProps = {
        beforeUpload: () => false,
        fileList,
        onChange: ({ fileList: newFileList }) => setFileList(newFileList.slice(-1)),
        maxCount: 1,
        showUploadList: { showPreviewIcon: false }
    };

    return (
        <Modal
            title={`Sənəd Əlavə Et - ${stockMovement?.product_name || 'Tarixçə'}`}
            open={open}
            onCancel={onCancel}
            width={600}
            footer={null}
        >
            <Form form={form} layout="vertical" onFinish={handleSubmit}>
                <Form.Item
                    name="title"
                    label="Sənəd başlığı"
                    rules={[{ required: true, message: 'Başlıq daxil edin' }]}
                >
                    <Input placeholder="Sənəd başlığı" />
                </Form.Item>

                <Form.Item
                    label="Fayl"
                    required
                >
                    <Upload {...uploadProps}>
                        <Button icon={<UploadOutlined />}>Fayl Seç</Button>
                    </Upload>
                </Form.Item>

                <Form.Item>
                    <Button type="primary" htmlType="submit" loading={submitting}>
                        Əlavə et
                    </Button>
                </Form.Item>
            </Form>

            {documents.length > 0 && (
                <>
                    <h4 style={{ marginTop: 24 }}>Mövcud Sənədlər</h4>
                    <Table
                        columns={columns}
                        dataSource={documents}
                        rowKey="id"
                        pagination={false}
                        size="small"
                        loading={loading}
                    />
                </>
            )}
        </Modal>
    );
};

export default StockMovementDocumentModal;
