import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Modal, Form, Input, Button, Select, Row, Col, DatePicker, Grid, Spin } from 'antd';
import styles from './style.module.scss';
import { TASK_STATUSES } from './constants';
import { getCustomer, getCustomerOptions } from '../../../../axios/api/tasks';

const { TextArea } = Input;

/** Desktop: ekrandan çıxmır; scroll yalnız .ant-modal-body-də */
const TASK_MODAL_MAX_HEIGHT = 'min(600px, 85vh)';

const CustomerRemoteSelect = ({ value, onChange }) => {
    const [open, setOpen] = useState(false);
    const [options, setOptions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [search, setSearch] = useState('');
    const [debouncedSearch, setDebouncedSearch] = useState('');
    const [page, setPage] = useState(1);
    const [hasNext, setHasNext] = useState(false);
    const lastRequestKeyRef = useRef('');

    useEffect(() => {
        const t = setTimeout(() => setDebouncedSearch(search), 500);
        return () => clearTimeout(t);
    }, [search]);

    const fetchPage = useCallback(async ({ nextPage, append }) => {
        const requestKey = `${debouncedSearch}::${nextPage}`;
        lastRequestKeyRef.current = requestKey;
        setLoading(true);
        try {
            const normalizedSearch = debouncedSearch.trim();
            const hasSearch = normalizedSearch.length >= 2;
            const res = await getCustomerOptions({
                search: hasSearch ? normalizedSearch : undefined,
                page: nextPage,
                page_size: 10,
                is_active: true,
            });
            // Drop outdated responses (fast typing)
            if (lastRequestKeyRef.current !== requestKey) return;
            const results = res.data?.results || [];
            setHasNext(!!res.data?.next);
            setPage(nextPage);
            setOptions((prev) => {
                const incoming = results.map((r) => ({
                    value: r.id,
                    label: r.label || r.full_name,
                }));
                if (!append) return incoming;
                const merged = [...prev];
                const seen = new Set(merged.map((x) => x.value));
                for (const item of incoming) {
                    if (!seen.has(item.value)) merged.push(item);
                }
                return merged;
            });
        } finally {
            setLoading(false);
        }
    }, [debouncedSearch]);

    // Load first page on open or search change
    useEffect(() => {
        if (!open) return;
        fetchPage({ nextPage: 1, append: false });
    }, [open, debouncedSearch, fetchPage]);

    // Ensure current value exists as an option (editing existing task)
    useEffect(() => {
        if (!value) return;
        if (options.some((o) => o.value === value)) return;
        (async () => {
            try {
                const res = await getCustomer(value);
                const c = res.data;
                const label = c?.register_number ? `${c.full_name} - ${c.register_number}` : c?.full_name;
                if (!label) return;
                setOptions((prev) => {
                    if (prev.some((o) => o.value === value)) return prev;
                    return [{ value, label }, ...prev];
                });
            } catch (_) {
                // ignore
            }
        })();
    }, [value, options]);

    const onPopupScroll = (e) => {
        const target = e.target;
        if (!target) return;
        const nearBottom = target.scrollTop + target.offsetHeight >= target.scrollHeight - 24;
        if (nearBottom && hasNext && !loading) {
            fetchPage({ nextPage: page + 1, append: true });
        }
    };

    return (
        <Select
            value={value}
            onChange={onChange}
            allowClear
            style={{ width: '100%' }}
            onClear={() => {
                onChange?.(undefined);
                setSearch('');
                setDebouncedSearch('');
            }}
            showSearch
            filterOption={false}
            placeholder="Müştəri seçin..."
            onSearch={setSearch}
            onDropdownVisibleChange={setOpen}
            options={options}
            notFoundContent={loading ? <Spin size="small" /> : null}
            onPopupScroll={onPopupScroll}
            loading={loading && options.length === 0}
        />
    );
};

const TaskModal = ({
    open,
    onCancel,
    onFinish,
    form,
    editingItem,
    groups,
    users,
    services,
    taskTypes = [],
    onEditCustomerAddress
}) => {
    const status = Form.useWatch('status', form);
    const selectedCustomerId = Form.useWatch('customer', form);
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
                    <Col xs={24} sm={12}>
                        <Form.Item name="title" label="Başlıq" rules={[{ required: true }]}>
                            <Input />
                        </Form.Item>
                    </Col>
                    <Col xs={24} sm={12}>
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
                </Row>

                <Row gutter={[16, 0]}>
                    <Col xs={24}>
                        <Form.Item name="customer" label="Müştəri" rules={[{ required: true }]}>
                            <CustomerRemoteSelect />
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

                {editingItem?.reporter_name ? (
                    <Row gutter={[16, 0]} style={{ marginBottom: 8 }}>
                        <Col span={24}>
                            <div style={{ fontSize: 12, color: 'rgba(0,0,0,0.45)', marginBottom: 4 }}>Reporter</div>
                            <div>{editingItem.reporter_name}</div>
                        </Col>
                    </Row>
                ) : null}

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

                {editingItem && status !== 'todo' && selectedCustomerId ? (
                    <Button
                        style={{ marginBottom: 12 }}
                        onClick={() =>
                            onEditCustomerAddress?.({
                                id: selectedCustomerId,
                                name: editingItem.customer_name,
                            })
                        }
                        block
                    >
                        Müştəri ünvanını redaktə et
                    </Button>
                ) : null}

                <Button type="primary" htmlType="submit" block>
                    Təsdiqlə
                </Button>
            </Form>
        </Modal >
    );
};

export default TaskModal;
