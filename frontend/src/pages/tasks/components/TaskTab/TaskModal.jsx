import React, { useEffect, useMemo } from 'react';
import { Modal, Form, Input, Button, Select, Row, Col, DatePicker, Grid } from 'antd';
import styles from './style.module.scss';
import { TASK_STATUSES } from './constants';

const { Option } = Select;
const { TextArea } = Input;

/** Desktop: ekrandan çıxmır; scroll yalnız .ant-modal-body-də */
const TASK_MODAL_MAX_HEIGHT = 'min(600px, 85vh)';

const TaskModal = ({
    open,
    onCancel,
    onFinish,
    form,
    editingItem,
    customers,
    groups,
    users,
    services,
    taskTypes = []
}) => {
    const status = Form.useWatch('status', form);
    const screens = Grid.useBreakpoint();
    const isDesktop = !!screens.md;
    const modalWidth = isDesktop ? 700 : '100%';

    /* Səhifə (html/body) scroll-unu kilidlə — arxa fon sürüşməsin */
    useEffect(() => {
        if (!open) return undefined;
        const prevHtmlOverflow = document.documentElement.style.overflow;
        const prevBodyOverflow = document.body.style.overflow;
        document.documentElement.style.overflow = 'hidden';
        document.body.style.overflow = 'hidden';
        return () => {
            document.documentElement.style.overflow = prevHtmlOverflow;
            document.body.style.overflow = prevBodyOverflow;
        };
    }, [open]);

    const modalStyles = useMemo(() => {
        if (!isDesktop) {
            return {
                wrapper: { overflow: 'hidden', maxHeight: '100vh' },
                content: {
                    maxHeight: '100vh',
                    height: '100vh',
                    display: 'flex',
                    flexDirection: 'column',
                    overflow: 'hidden',
                    borderRadius: 0,
                    padding: 0
                },
                header: { flexShrink: 0 },
                body: {
                    flex: 1,
                    minHeight: 0,
                    overflowY: 'auto',
                    overflowX: 'hidden'
                }
            };
        }
        return {
            /* wrapper 60vh kimi məhdud olmasın — məzmun kəsilməsin */
            wrapper: { overflow: 'hidden', maxHeight: '100vh' },
            container: {
                maxHeight: TASK_MODAL_MAX_HEIGHT,
                minHeight: 0,
                overflow: 'hidden',
                display: 'flex',
                flexDirection: 'column'
            },
            content: {
                maxHeight: TASK_MODAL_MAX_HEIGHT,
                height: 'auto',
                minHeight: 0,
                display: 'flex',
                flexDirection: 'column',
                overflow: 'hidden',
                flex: '1 1 auto'
            },
            header: { flexShrink: 0, flex: '0 0 auto' },
            body: {
                flex: '1 1 auto',
                minHeight: 0,
                maxHeight: '100%',
                overflowY: 'auto',
                overflowX: 'hidden',
                position: 'relative'
            }
        };
    }, [isDesktop]);

    return (
        <Modal
            title={editingItem ? "Tapşırığı Düzəlt" : "Yeni Tapşırıq"}
            open={open}
            onCancel={onCancel}
            footer={null}
            width={modalWidth}
            centered={isDesktop}
            className={styles.responsiveModal}
            styles={modalStyles}
            style={
                !isDesktop
                    ? { top: 0, paddingBottom: 0, margin: 0, maxWidth: '100vw' }
                    : undefined
            }
            destroyOnClose
        >
            <Form form={form} onFinish={onFinish} layout="vertical">
                <Row gutter={[16, 0]}>
                    <Col xs={24} sm={8}>
                        <Form.Item name="title" label="Başlıq" rules={[{ required: true }]}>
                            <Input />
                        </Form.Item>
                    </Col>
                    <Col xs={24} sm={8}>
                        <Form.Item name="task_type" label="Növ">
                            <Select allowClear>
                                {taskTypes.map(t => (
                                    <Option key={t.id} value={t.id}>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                            <div style={{ width: 12, height: 12, borderRadius: '50%', backgroundColor: t.color }} />
                                            {t.name}
                                        </div>
                                    </Option>
                                ))}
                            </Select>
                        </Form.Item>
                    </Col>
                    <Col xs={24} sm={8}>
                        <Form.Item name="customer" label="Müştəri" rules={[{ required: true }]}>
                            <Select
                                showSearch
                                filterOption={(input, option) => {
                                    const customer = customers.find(c => c.id === option.value);
                                    if (!customer) return false;
                                    const searchText = input.toLowerCase();
                                    const name = (customer.full_name || '').toLowerCase();
                                    const regNum = (customer.register_number || '').toLowerCase();
                                    return name.includes(searchText) || regNum.includes(searchText);
                                }}
                            >
                                {customers.filter(c => c.is_active).map(c => (
                                    <Option key={c.id} value={c.id}>
                                        {c.full_name}{c.register_number ? ` - ${c.register_number}` : ''}
                                    </Option>
                                ))}
                            </Select>
                        </Form.Item>
                    </Col>
                </Row>

                <Row gutter={[16, 0]}>
                    <Col xs={24} sm={12}>
                        <Form.Item
                            name="status"
                            label="Status"
                            initialValue="todo"
                            rules={[{ required: true }]}
                        >
                            <Select
                                onChange={(v) => {
                                    if (v !== 'pending') {
                                        form.setFieldValue('rescheduled_date', undefined);
                                    }
                                }}
                            >
                                {TASK_STATUSES.map(s => (
                                    <Option key={s.value} value={s.value}>
                                        <span style={{ color: s.color, marginRight: 8 }}>●</span>
                                        {s.label}
                                    </Option>
                                ))}
                            </Select>
                        </Form.Item>
                    </Col>
                    {status === 'pending' && (
                        <Col xs={24} sm={12}>
                            <Form.Item
                                name="rescheduled_date"
                                label="Rescheduled date"
                                rules={[{ required: true, message: 'Təxirə salındı üçün tarix seçin' }]}
                            >
                                <DatePicker style={{ width: '100%' }} format="YYYY-MM-DD" placeholder="Tarix seçin" />
                            </Form.Item>
                        </Col>
                    )}
                </Row>

                <Row gutter={[16, 0]}>
                    <Col xs={24} md={12}>
                        <Form.Item name="group" label="Qrup">
                            <Select showSearch optionFilterProp="children">
                                {groups.map(g => (
                                    <Option key={g.id} value={g.id}>{g.region_name} - {g.name}</Option>
                                ))}
                            </Select>
                        </Form.Item>
                    </Col>
                    <Col xs={24} md={12}>
                        <Form.Item name="assigned_to" label="İcraçılar">
                            <Select
                                mode="multiple"
                                allowClear
                                showSearch
                                optionFilterProp="children"
                                placeholder="İcraçıları seçin"
                            >
                                {users.filter(u => u.is_active).map(u => (
                                    <Option key={u.id} value={u.id}>{u.first_name} {u.last_name}</Option>
                                ))}
                            </Select>
                        </Form.Item>
                    </Col>
                </Row>

                <Row gutter={[16, 0]}>
                    <Col span={24}>
                        <Form.Item name="services" label="Servislər">
                            <Select
                                mode="multiple"
                                placeholder="Servisləri seçin"
                                optionFilterProp="children"
                            >
                                {services.filter(s => s.is_active).map(s => (
                                    <Option key={s.id} value={s.id}>{s.name}</Option>
                                ))}
                            </Select>
                        </Form.Item>
                    </Col>
                </Row>

                <Form.Item name="note" label="Qeyd">
                    <TextArea rows={3} />
                </Form.Item>

                <Button type="primary" htmlType="submit" block>
                    Təsdiqlə
                </Button>
            </Form>
        </Modal >
    );
};

export default TaskModal;
