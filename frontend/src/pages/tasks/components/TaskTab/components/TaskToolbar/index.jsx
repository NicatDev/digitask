import React from 'react';
import { Input, Button, Select, Grid } from 'antd';
import { FilterOutlined } from '@ant-design/icons';
import { TASK_STATUSES } from '../../constants';

const { Option } = Select;

const TaskToolbar = ({
    searchText,
    setSearchText,
    showFilters,
    setShowFilters,
    statusFilter,
    setStatusFilter,
    customerFilter,
    setCustomerFilter,
    isActiveFilter,
    setIsActiveFilter,
    customers,
    onNewTask
}) => {
    const screens = Grid.useBreakpoint();

    return (
        <div style={{ marginBottom: 16, background: '#fff', padding: '16px', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{
                display: 'flex',
                flexDirection: screens.md ? 'row' : 'column',
                justifyContent: 'space-between',
                alignItems: screens.md ? 'center' : 'stretch',
                gap: '8px'
            }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', width: screens.md ? 'auto' : '100%' }}>
                    <Input.Search
                        placeholder="Axtar..."
                        value={searchText}
                        onChange={(e) => setSearchText(e.target.value)}
                        style={{ width: screens.md ? 250 : '100%' }}
                    />
                    {!screens.md && (
                        <Button
                            icon={<FilterOutlined />}
                            onClick={() => setShowFilters(!showFilters)}
                        />
                    )}
                </div>

                <div style={{
                    display: 'flex',
                    flexDirection: screens.md ? 'row' : 'column',
                    gap: '8px',
                    flexWrap: 'wrap',
                    alignItems: screens.md ? 'center' : 'stretch',
                    width: screens.md ? 'auto' : '100%'
                }}>
                    {(screens.md || showFilters) && (
                        <>
                            <Select
                                placeholder="Status"
                                style={{ width: screens.md ? 140 : '100%' }}
                                allowClear
                                value={statusFilter}
                                onChange={setStatusFilter}
                            >
                                {TASK_STATUSES.map(s => (
                                    <Option key={s.value} value={s.value}>
                                        <span style={{ color: s.color, marginRight: 8 }}>●</span>
                                        {s.label}
                                    </Option>
                                ))}
                            </Select>
                            <Select
                                placeholder="Müştəri"
                                style={{ width: screens.md ? 150 : '100%' }}
                                allowClear
                                showSearch
                                optionFilterProp="children"
                                value={customerFilter}
                                onChange={setCustomerFilter}
                            >
                                {customers.map(c => (
                                    <Option key={c.id} value={c.id}>{c.full_name}</Option>
                                ))}
                            </Select>
                            <Select
                                placeholder="Aktivlik"
                                style={{ width: screens.md ? 100 : '100%' }}
                                allowClear={false}
                                value={isActiveFilter}
                                onChange={setIsActiveFilter}
                            >
                                <Option value="all">Hamısı</Option>
                                <Option value={true}>Aktiv</Option>
                                <Option value={false}>Deaktiv</Option>
                            </Select>
                        </>
                    )}
                    <Button type="primary" block={!screens.md} onClick={onNewTask}>
                        Yeni Tapşırıq
                    </Button>
                </div>
            </div>
        </div>
    );
};

export default TaskToolbar;
