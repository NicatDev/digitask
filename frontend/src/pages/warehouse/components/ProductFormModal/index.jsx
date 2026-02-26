import React, { useEffect, useState } from 'react';
import dayjs from 'dayjs';
import { Modal, Form, Input, Button, Select, Switch, InputNumber, Row, Col, DatePicker } from 'antd';
import { createProduct, updateProduct } from '../../../../axios/api/warehouse/index';
import { handleApiError } from '../../../../utils/errorHandler';

const { Option } = Select;

const ProductFormModal = ({ open, onClose, editingItem, categories, onSuccess }) => {
    const [form] = Form.useForm();
    const [selectedCategory, setSelectedCategory] = useState(null);

    useEffect(() => {
        if (open && editingItem) {
            const cat = categories.find(c => c.id === editingItem.category);
            setSelectedCategory(cat || null);
            const fv = { ...editingItem };
            if (cat?.fields_list && editingItem.category_data) {
                cat.fields_list.forEach(f => {
                    let val = editingItem.category_data[f.name];
                    if (f.field_type === 'date' && val) val = dayjs(val);
                    fv[`cf_${f.id}`] = val;
                });
            }
            form.setFieldsValue(fv);
        } else if (open) {
            form.resetFields();
            setSelectedCategory(null);
        }
    }, [open, editingItem]);

    const formCategory = Form.useWatch('category', form);
    useEffect(() => {
        const cat = formCategory ? categories.find(c => c.id === formCategory) : null;
        setSelectedCategory(cat || null);
    }, [formCategory, categories]);

    const onFinish = async (values) => {
        try {
            const cat = categories.find(c => c.id === values.category);
            if (cat?.fields_list) {
                const categoryData = {};
                cat.fields_list.forEach(f => {
                    const key = `cf_${f.id}`;
                    if (values[key] !== undefined && values[key] !== null) {
                        categoryData[f.name] = f.field_type === 'date' && values[key]?.format
                            ? values[key].format('YYYY-MM-DD') : values[key];
                    }
                    delete values[key];
                });
                values.category_data = categoryData;
            }
            if (editingItem) {
                await updateProduct(editingItem.id, values);
            } else {
                await createProduct(values);
            }
            onSuccess();
            onClose();
        } catch (e) {
            handleApiError(e, 'Əməliyyat uğursuz oldu');
        }
    };

    return (
        <Modal
            title={editingItem ? "Məhsulu Düzəlt" : "Yeni Məhsul"}
            open={open} onCancel={onClose} footer={null} width={800} destroyOnClose
        >
            <div style={{ maxHeight: '70vh', overflowY: 'auto', paddingRight: 8 }}>
                <Form form={form} onFinish={onFinish} layout="vertical">
                    <Row gutter={16}>
                        <Col span={12}><Form.Item name="name" label="Ad" rules={[{ required: true }]}><Input /></Form.Item></Col>
                        <Col span={12}>
                            <Form.Item name="unit" label="Ölçü Vahidi" rules={[{ required: true }]} initialValue="pcs">
                                <Select>
                                    <Option value="pcs">Ədəd</Option><Option value="kg">Kq</Option><Option value="g">Qram</Option>
                                    <Option value="l">Litr</Option><Option value="m">Metr</Option><Option value="box">Qutu</Option><Option value="set">Dəst</Option>
                                </Select>
                            </Form.Item>
                        </Col>
                    </Row>
                    <Row gutter={16}>
                        <Col span={8}><Form.Item name="brand" label="Brand"><Input /></Form.Item></Col>
                        <Col span={8}><Form.Item name="model" label="Model"><Input /></Form.Item></Col>
                        <Col span={8}><Form.Item name="has_serial_number" label="Serial Nömrəli" valuePropName="checked"><Switch /></Form.Item></Col>
                    </Row>
                    <Row gutter={16}>
                        <Col span={6}><Form.Item name="size" label="Ölçü"><Input /></Form.Item></Col>
                        <Col span={6}><Form.Item name="weight" label="Çəki"><Input /></Form.Item></Col>
                        <Col span={6}><Form.Item name="port_count" label="Port Sayı"><InputNumber style={{ width: '100%' }} /></Form.Item></Col>
                        <Col span={6}><Form.Item name="price" label="Qiymət"><InputNumber style={{ width: '100%' }} step="0.01" /></Form.Item></Col>
                    </Row>
                    <Row gutter={16}>
                        <Col span={8}><Form.Item name="min_quantity" label="Min Say"><InputNumber style={{ width: '100%' }} /></Form.Item></Col>
                        <Col span={8}><Form.Item name="max_quantity" label="Max Say"><InputNumber style={{ width: '100%' }} /></Form.Item></Col>
                        <Col span={8}>
                            <Form.Item name="category" label="Kateqoriya">
                                <Select allowClear placeholder="Kateqoriya seçin">
                                    {categories.map(c => <Option key={c.id} value={c.id}>{c.name}</Option>)}
                                </Select>
                            </Form.Item>
                        </Col>
                    </Row>
                    {selectedCategory?.fields_list?.length > 0 && (
                        <>
                            <div style={{ marginBottom: 8, fontWeight: 600, color: '#1890ff' }}>{selectedCategory.name} sahələri</div>
                            <Row gutter={16}>
                                {selectedCategory.fields_list.map(f => (
                                    <Col span={8} key={f.id}>
                                        <Form.Item name={`cf_${f.id}`} label={f.name}
                                            rules={f.is_required ? [{ required: true, message: `${f.name} tələb olunur` }] : []}
                                            {...(f.field_type === 'boolean' ? { valuePropName: 'checked' } : {})}>
                                            {f.field_type === 'string' && <Input />}
                                            {f.field_type === 'number' && <InputNumber style={{ width: '100%' }} />}
                                            {f.field_type === 'boolean' && <Switch />}
                                            {f.field_type === 'date' && <DatePicker style={{ width: '100%' }} />}
                                        </Form.Item>
                                    </Col>
                                ))}
                            </Row>
                        </>
                    )}
                    <Form.Item name="description" label="Təsvir"><Input.TextArea /></Form.Item>
                    <Button type="primary" htmlType="submit" block>Təsdiqlə</Button>
                </Form>
            </div>
        </Modal>
    );
};

export default ProductFormModal;
