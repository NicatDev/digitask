import React, { useEffect, useState } from 'react';
import { Modal, Form, Input, Button, Divider, InputNumber, Checkbox, DatePicker, message, Upload, List, Card, Tag } from 'antd';
import { UploadOutlined, LeftOutlined, CheckCircleOutlined, EditOutlined, FormOutlined } from '@ant-design/icons';
import * as Icons from '@ant-design/icons';
import dayjs from 'dayjs';
import styles from './style.module.scss';
import { createTaskService, updateTaskService, getTaskServices } from '../../../../../axios/api/tasks';

const { TextArea } = Input;

// Dynamic icon component renderer (reused)
const DynamicIcon = ({ iconName, style }) => {
    const IconComponent = Icons[iconName];
    if (!IconComponent) return null;
    return <IconComponent style={style} />;
};

// Helper to get full URL (dynamic based on environment)
const getFullUrl = (path) => {
    if (!path) return '';
    if (path.startsWith('http')) return path;
    const cleanPath = path.startsWith('/') ? path.substring(1) : path;
    const isProduction = window.location.hostname === 'new.digitask.store' ||
        window.location.hostname === 'digitask.store' ||
        window.location.hostname === 'app.digitask.store';
    const baseUrl = isProduction ? 'https://app.digitask.store' : 'http://127.0.0.1:8000';
    return `${baseUrl}/${cleanPath}`;
};

const QuestionnaireModal = ({
    open,
    onCancel,
    task,
    assignedServices, // List of {id, name, icon} from task.services
    allColumns, // All columns, will filter by service
}) => {
    const [viewMode, setViewMode] = useState('list'); // 'list' or 'form'
    const [selectedServiceId, setSelectedServiceId] = useState(null);
    const [loading, setLoading] = useState(false);
    const [form] = Form.useForm();
    const [existingTaskServices, setExistingTaskServices] = useState([]);
    const [currentTaskServiceId, setCurrentTaskServiceId] = useState(null);

    useEffect(() => {
        if (open && task) {
            setViewMode('list');
            fetchTaskServices();
        }
        if (!open) {
            setSelectedServiceId(null);
            setCurrentTaskServiceId(null);
            setExistingTaskServices([]);
            form.resetFields();
            setViewMode('list');
        }
    }, [open, task]);

    const fetchTaskServices = async () => {
        try {
            setLoading(true);
            const res = await getTaskServices({ task: task.id });
            const results = res.data.results || res.data;
            setExistingTaskServices(results);
        } catch (error) {
            console.error(error);
            message.error('Mövcud anketləri yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    const handleServiceSelect = (serviceId) => {
        setSelectedServiceId(serviceId);

        // Check if exists
        const existing = existingTaskServices.find(ts => ts.service === serviceId);
        if (existing) {
            setCurrentTaskServiceId(existing.id);
            // Pre-fill form
            const formValues = { note: existing.note };
            existing.values.forEach(v => {
                const fieldName = `col_${v.column}`;
                const colDef = allColumns.find(c => c.id === v.column);
                if (colDef) {
                    let val = null;
                    if (colDef.field_type === 'date') val = v.date_value ? dayjs(v.date_value) : null;
                    else if (colDef.field_type === 'datetime') val = v.datetime_value ? dayjs(v.datetime_value) : null;
                    else if (colDef.field_type === 'image') {
                        val = v.image_value ? [{
                            uid: '-1',
                            name: 'Image',
                            status: 'done',
                            url: getFullUrl(v.image_value),
                            thumbUrl: getFullUrl(v.image_value)
                        }] : [];
                    }
                    else if (colDef.field_type === 'file') {
                        val = v.file_value ? [{
                            uid: '-1',
                            name: 'File',
                            status: 'done',
                            url: getFullUrl(v.file_value)
                        }] : [];
                    }
                    else if (colDef.field_type === 'boolean') val = v.boolean_value;
                    else if (colDef.field_type === 'integer') val = v.number_value;
                    else if (colDef.field_type === 'decimal') val = v.decimal_value ? parseFloat(v.decimal_value) : null;
                    else if (colDef.field_type === 'text') val = v.text_value;
                    else val = v.charfield_value;

                    formValues[fieldName] = val;
                }
            });
            form.setFieldsValue(formValues);
        } else {
            setCurrentTaskServiceId(null);
            form.resetFields();
        }

        setViewMode('form');
    };

    const handleBackToList = () => {
        setViewMode('list');
        setSelectedServiceId(null);
        setCurrentTaskServiceId(null);
        form.resetFields();
    };

    const getServiceColumns = (serviceId) => {
        return allColumns.filter(col => col.service === serviceId && col.is_active);
    };

    const onFinish = async (values) => {
        setLoading(true);
        try {
            const formData = new FormData();
            formData.append('task', task.id);
            formData.append('service', selectedServiceId);
            formData.append('note', values.note || '');

            const serviceCols = getServiceColumns(selectedServiceId);
            const valuesJsonList = [];

            serviceCols.forEach(col => {
                const fieldName = `col_${col.id}`;
                const val = values[fieldName];
                if (val === undefined || val === null) return;

                if (col.field_type === 'image' || col.field_type === 'file') {
                    if (val && val.length > 0) {
                        const fileObj = val[0].originFileObj;
                        if (fileObj) {
                            formData.append(`file_${col.id}`, fileObj);
                            valuesJsonList.push({ column: col.id });
                        }
                    }
                } else {
                    let valueKey = 'charfield_value';
                    if (col.field_type === 'text') valueKey = 'text_value';
                    else if (col.field_type === 'integer') valueKey = 'number_value';
                    else if (col.field_type === 'decimal') valueKey = 'decimal_value';
                    else if (col.field_type === 'boolean') valueKey = 'boolean_value';
                    else if (col.field_type === 'date') valueKey = 'date_value';
                    else if (col.field_type === 'datetime') valueKey = 'datetime_value';

                    let simpleVal = val;
                    if (val && (col.field_type === 'date' || col.field_type === 'datetime')) {
                        try {
                            if (val.format) simpleVal = val.format(col.field_type === 'date' ? 'YYYY-MM-DD' : 'YYYY-MM-DDTHH:mm:ss');
                        } catch (e) { }
                    }

                    valuesJsonList.push({
                        column: col.id,
                        [valueKey]: simpleVal
                    });
                }
            });

            formData.append('values_json', JSON.stringify(valuesJsonList));

            if (currentTaskServiceId) {
                await updateTaskService(currentTaskServiceId, formData);
                message.success('Anket yeniləndi');
            } else {
                const res = await createTaskService(formData);
                setExistingTaskServices(prev => {
                    const idx = prev.findIndex(item => item.id === res.data.id);
                    if (idx > -1) {
                        const newList = [...prev];
                        newList[idx] = res.data;
                        return newList;
                    }
                    return [...prev, res.data];
                });
                setCurrentTaskServiceId(res.data.id);
                message.success('Anket yadda saxlanıldı');
            }
            // Refresh list to show updated status
            fetchTaskServices();
            handleBackToList(); // Go back to list after success

        } catch (error) {
            console.error(error);
            message.error('Xəta baş verdi');
        } finally {
            setLoading(false);
        }
    };

    const normFile = (e) => {
        if (Array.isArray(e)) return e;
        return e?.fileList;
    };

    // --- RENDER LIST VIEW ---
    const renderServiceList = () => {
        return (
            <div style={{ padding: '0 16px' }}>
                <List
                    grid={{ gutter: 16, column: 1 }}
                    dataSource={assignedServices}
                    renderItem={service => {
                        const isFilled = existingTaskServices.some(ts => ts.service === service.id);
                        return (
                            <List.Item>
                                <Card
                                    hoverable
                                    className={styles.serviceItemCard}
                                    onClick={() => handleServiceSelect(service.id)}
                                >
                                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
                                            <div style={{
                                                width: 48, height: 48,
                                                background: '#f0f5ff',
                                                borderRadius: 8,
                                                display: 'flex', alignItems: 'center', justifyContent: 'center'
                                            }}>
                                                {service.icon ? (
                                                    <DynamicIcon iconName={service.icon} style={{ fontSize: 24, color: '#1890ff' }} />
                                                ) : (
                                                    <span style={{ fontSize: 20, fontWeight: 'bold', color: '#1890ff' }}>
                                                        {service.name.charAt(0)}
                                                    </span>
                                                )}
                                            </div>
                                            <div>
                                                <div style={{ fontSize: 16, fontWeight: 500 }}>{service.name}</div>
                                                <div style={{ fontSize: 13, color: '#8c8c8c' }}>
                                                    {isFilled ? 'Doldurulub' : 'Doldurulmayıb'}
                                                </div>
                                            </div>
                                        </div>
                                        <div>
                                            {isFilled ? (
                                                <Tag color="success" icon={<CheckCircleOutlined />}>Tamamlandı</Tag>
                                            ) : (
                                                <Button type="primary" size="small" icon={<EditOutlined />}>
                                                    Doldur
                                                </Button>
                                            )}
                                        </div>
                                    </div>
                                </Card>
                            </List.Item>
                        );
                    }}
                />
            </div>
        );
    };

    // --- RENDER FORM VIEW ---
    const renderFormView = () => {
        const service = assignedServices.find(s => s.id === selectedServiceId);
        return (
            <div>
                <div style={{ display: 'flex', alignItems: 'center', marginBottom: 24, padding: '0 16px' }}>
                    <Button icon={<LeftOutlined />} onClick={handleBackToList} style={{ marginRight: 16 }}>Geri</Button>
                    <h3 style={{ margin: 0 }}>{service?.name} Anketi</h3>
                </div>

                <Form form={form} layout="vertical" onFinish={onFinish} style={{ padding: '0 16px' }}>
                    {getServiceColumns(selectedServiceId).map(col => (
                        <Form.Item
                            key={col.id}
                            label={col.name}
                            name={`col_${col.id}`}
                            required={col.required}
                            valuePropName={col.field_type === 'boolean' ? 'checked' : (col.field_type === 'image' || col.field_type === 'file') ? 'fileList' : 'value'}
                            getValueFromEvent={(col.field_type === 'image' || col.field_type === 'file') ? normFile : undefined}
                            rules={[
                                { required: col.required, message: `${col.name} xanasını doldurun` },
                                col.field_type === 'integer' && { type: 'integer', message: 'Zəhmət olmasa tam ədəd daxil edin' },
                                col.field_type === 'decimal' && { type: 'number', message: 'Zəhmət olmasa rəqəm daxil edin' }
                            ].filter(Boolean)}
                        >
                            {col.field_type === 'string' && <Input />}
                            {col.field_type === 'text' && <TextArea rows={3} />}
                            {col.field_type === 'integer' && (
                                <InputNumber
                                    style={{ width: '100%' }}
                                    precision={0}
                                    onKeyPress={(event) => {
                                        if (!/[0-9]/.test(event.key)) {
                                            event.preventDefault();
                                        }
                                    }}
                                />
                            )}
                            {col.field_type === 'decimal' && (
                                <InputNumber
                                    style={{ width: '100%' }}
                                    step="0.01"
                                    onKeyPress={(event) => {
                                        // Allow numbers and one dot
                                        if (!/[0-9.]/.test(event.key)) {
                                            event.preventDefault();
                                        }
                                    }}
                                />
                            )}
                            {col.field_type === 'boolean' && <Checkbox />}
                            {col.field_type === 'date' && <DatePicker style={{ width: '100%' }} />}
                            {/* Datetime could use DatePicker showTime */}
                            {col.field_type === 'datetime' && <DatePicker showTime style={{ width: '100%' }} />}
                            {(col.field_type === 'image' || col.field_type === 'file') && (
                                <Upload
                                    listType={col.field_type === 'image' ? 'picture-card' : 'text'}
                                    maxCount={1}
                                    beforeUpload={() => false}
                                >
                                    <div>
                                        <UploadOutlined />
                                        <div style={{ marginTop: 8 }}>Yüklə</div>
                                    </div>
                                </Upload>
                            )}
                        </Form.Item>
                    ))}

                    <Form.Item name="note" label="Qeyd">
                        <TextArea rows={2} />
                    </Form.Item>

                    <Button type="primary" htmlType="submit" block loading={loading} icon={<CheckCircleOutlined />}>
                        Yadda Saxla
                    </Button>
                </Form>
            </div>
        );
    };

    return (
        <Modal
            title={null}
            open={open}
            onCancel={onCancel}
            footer={null}
            width={700}
            destroyOnClose
            className={styles.questionnaireModal}
            styles={{ body: { maxHeight: '70vh', overflowY: 'auto' } }}
        >
            <div style={{ paddingTop: 20 }}>
                {viewMode === 'list' ? (
                    <>
                        <h3 style={{ padding: '0 16px', marginBottom: 20 }}>Tapşırıq Anketləri: {task?.title}</h3>
                        {renderServiceList()}
                    </>
                ) : (
                    renderFormView()
                )}
            </div>
        </Modal>
    );
};

export default QuestionnaireModal;
