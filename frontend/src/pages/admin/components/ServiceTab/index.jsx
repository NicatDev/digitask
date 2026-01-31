import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Switch, Grid, Select } from 'antd';
import { FilterOutlined } from '@ant-design/icons';
import * as Icons from '@ant-design/icons';
import styles from './style.module.scss';
import { getServices, createService, updateService, deleteService } from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';

// Service-related icons for selection
const SERVICE_ICONS = [
    // Communication & Voice
    { name: 'AudioOutlined', label: 'Səs / Audio' },
    { name: 'SoundOutlined', label: 'Səs Dalğası' },
    { name: 'CustomerServiceOutlined', label: 'Müştəri Xidməti' },
    { name: 'PhoneOutlined', label: 'Telefon' },
    { name: 'MobileOutlined', label: 'Mobil' },
    { name: 'MessageOutlined', label: 'Mesaj' },
    { name: 'CommentOutlined', label: 'Şərh' },
    { name: 'NotificationOutlined', label: 'Bildiriş' },

    // Internet & Network
    { name: 'WifiOutlined', label: 'Wi-Fi / Internet' },
    { name: 'GlobalOutlined', label: 'Global / Internet' },
    { name: 'CloudOutlined', label: 'Cloud / Bulud' },
    { name: 'ApiOutlined', label: 'API / Əlaqə' },
    { name: 'LinkOutlined', label: 'Link / Bağlantı' },
    { name: 'SignalFilled', label: 'Siqnal' },

    // TV & Media
    { name: 'DesktopOutlined', label: 'TV / Monitor' },
    { name: 'PlaySquareOutlined', label: 'TV Kanalları' },
    { name: 'VideoCameraOutlined', label: 'Video / Kamera' },
    { name: 'PlayCircleOutlined', label: 'Play / Oynat' },
    { name: 'YoutubeOutlined', label: 'YouTube / Video' },
    { name: 'CameraOutlined', label: 'Kamera' },
    { name: 'PictureOutlined', label: 'Şəkil' },

    // Devices
    { name: 'LaptopOutlined', label: 'Laptop' },
    { name: 'TabletOutlined', label: 'Tablet' },
    { name: 'PrinterOutlined', label: 'Printer' },
    { name: 'UsbOutlined', label: 'USB' },
    { name: 'HddOutlined', label: 'Disk / HDD' },

    // Technical & Tools
    { name: 'ToolOutlined', label: 'Təmir / Alət' },
    { name: 'SettingOutlined', label: 'Parametrlər' },
    { name: 'ThunderboltOutlined', label: 'Elektrik' },
    { name: 'BulbOutlined', label: 'İşıq / İdea' },
    { name: 'DatabaseOutlined', label: 'Database' },
    { name: 'CodeOutlined', label: 'Kod / Proqram' },

    // Location & Buildings
    { name: 'HomeOutlined', label: 'Ev' },
    { name: 'ShopOutlined', label: 'Mağaza' },
    { name: 'BankOutlined', label: 'Bank / Ofis' },
    { name: 'EnvironmentOutlined', label: 'Yer / Lokasiya' },
    { name: 'BuildOutlined', label: 'Tikinti' },
    { name: 'ApartmentOutlined', label: 'Bina / Şirkət' },

    // Transport
    { name: 'CarOutlined', label: 'Avtomobil' },
    { name: 'RocketOutlined', label: 'Sürətli Xidmət' },

    // Security & Safety
    { name: 'SafetyOutlined', label: 'Təhlükəsizlik' },
    { name: 'LockOutlined', label: 'Kilid' },
    { name: 'EyeOutlined', label: 'Nəzarət' },
    { name: 'SecurityScanOutlined', label: 'Skan' },

    // Other Services
    { name: 'AppstoreOutlined', label: 'Tətbiq' },
    { name: 'ExperimentOutlined', label: 'Laboratoriya' },
    { name: 'GiftOutlined', label: 'Hədiyyə' },
    { name: 'DollarOutlined', label: 'Ödəniş' },
    { name: 'CreditCardOutlined', label: 'Kart' },
    { name: 'ClockCircleOutlined', label: 'Saat / Vaxt' },
    { name: 'CalendarOutlined', label: 'Təqvim' },
    { name: 'TeamOutlined', label: 'Komanda' },
    { name: 'UserOutlined', label: 'İstifadəçi' },
];

// Dynamic icon component renderer
const DynamicIcon = ({ iconName, style }) => {
    const IconComponent = Icons[iconName];
    if (!IconComponent) return null;
    return <IconComponent style={style} />;
};

const ServiceTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [statusFilter, setStatusFilter] = useState('all');
    const [showFilters, setShowFilters] = useState(false);
    const screens = Grid.useBreakpoint();

    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [form] = Form.useForm();

    // Debounce Search
    useEffect(() => {
        const timer = setTimeout(() => {
            setDebouncedSearchText(searchText);
        }, 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    const fetchData = async () => {
        setLoading(true);
        try {
            const res = await getServices();
            setData(res.data.results || res.data);
        } catch (error) {
            console.error(error);
            handleApiError(error, 'Məlumatları yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (isActive) {
            fetchData();
        }
    }, [isActive]);

    const handleDelete = async (id) => {
        try {
            await deleteService(id);
            message.success('Servis silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    const onFinish = async (values) => {
        try {
            if (editingItem) {
                await updateService(editingItem.id, values);
                message.success('Servis yeniləndi');
            } else {
                await createService(values);
                message.success('Servis yaradıldı');
            }
            setIsModalOpen(false);
            form.resetFields();
            setEditingItem(null);
            fetchData();
        } catch (error) {
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        }
    };

    const handleStatusChange = async (id, checked) => {
        try {
            await updateService(id, { is_active: checked });
            message.success('Status yeniləndi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const getFilteredData = () => {
        return data.filter(item => {
            const lowerSearch = debouncedSearchText.toLowerCase();
            const matchesSearch = item.name.toLowerCase().includes(lowerSearch) ||
                (item.description && item.description.toLowerCase().includes(lowerSearch));
            const matchesStatus = statusFilter !== 'all' ? item.is_active === statusFilter : true;
            return matchesSearch && matchesStatus;
        });
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        {
            title: 'İkon',
            dataIndex: 'icon',
            key: 'icon',
            width: 90,
            render: (icon) => <DynamicIcon iconName={icon} style={{ fontSize: 24 }} />
        },
        { title: 'Ad', dataIndex: 'name', key: 'name' },
        { title: 'Təsvir', dataIndex: 'description', key: 'description', ellipsis: true },
        { title: 'Sütun Sayı', dataIndex: 'columns_count', key: 'columns_count', width: 100 },
        {
            title: 'Aktiv',
            dataIndex: 'is_active',
            key: 'is_active',
            render: (active, record) => (
                <Switch
                    checked={active}
                    onChange={(checked) => handleStatusChange(record.id, checked)}
                />
            )
        },
        {
            title: 'Əməliyyat',
            key: 'action',
            render: (_, record) => (
                <>
                    <Button type="link" onClick={() => {
                        setEditingItem(record);
                        form.setFieldsValue(record);
                        setIsModalOpen(true);
                    }}>Düzəliş</Button>
                    <Popconfirm title="Silmək istədiyinizə əminsiniz?" onConfirm={() => handleDelete(record.id)}>
                        <Button type="link" danger>Sil</Button>
                    </Popconfirm>
                </>
            ),
        },
    ];

    return (
        <div>
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
                            onChange={(e) => setSearchText(e.target.value)}
                            style={{ width: screens.md ? 250 : '100%' }}
                        />
                        {/* Mobile Filter Toggle */}
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
                        {/* Filters Conditionally Hidden on Mobile */}
                        {(screens.md || showFilters) && (
                            <Select
                                placeholder="Status"
                                style={{ width: screens.md ? 120 : '100%' }}
                                value={statusFilter}
                                onChange={setStatusFilter}
                            >
                                <Select.Option value="all">Hamısı</Select.Option>
                                <Select.Option value={true}>Aktiv</Select.Option>
                                <Select.Option value={false}>Deaktiv</Select.Option>
                            </Select>
                        )}
                        <Button type="primary" block={!screens.md} onClick={() => {
                            setEditingItem(null);
                            form.resetFields();
                            setIsModalOpen(true);
                        }}>
                            Yeni Servis
                        </Button>
                    </div>
                </div>
            </div>

            <Table
                columns={columns}
                dataSource={getFilteredData()}
                rowKey="id"
                loading={loading}
                scroll={{ x: 800 }}
                pagination={{ pageSize: 10 }}
            />

            <Modal
                title={editingItem ? "Servisi Düzəlt" : "Yeni Servis"}
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                footer={null}
                width={600}
                className={styles.responsiveModal}
            >
                <Form form={form} onFinish={onFinish} layout="vertical" initialValues={{ icon: 'AppstoreOutlined' }}>
                    <Form.Item name="name" label="Ad" rules={[{ required: true }]}>
                        <Input />
                    </Form.Item>
                    <Form.Item name="icon" label="İkon" rules={[{ required: true }]}>
                        <Select
                            showSearch
                            optionFilterProp="label"
                            optionLabelProp="label"
                        >
                            {SERVICE_ICONS.map(icon => (
                                <Select.Option key={icon.name} value={icon.name} label={icon.label}>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                        <DynamicIcon iconName={icon.name} style={{ fontSize: 20 }} />
                                        <span>{icon.label}</span>
                                    </div>
                                </Select.Option>
                            ))}
                        </Select>
                    </Form.Item>
                    <Form.Item name="description" label="Təsvir">
                        <Input.TextArea rows={3} />
                    </Form.Item>

                    <Button type="primary" htmlType="submit" block>
                        Təsdiqlə
                    </Button>
                </Form>
            </Modal>
        </div>
    );
};

export default ServiceTab;
