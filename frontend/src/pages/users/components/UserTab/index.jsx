import React, { useEffect, useState } from 'react';
import UserLocationModal from './UserLocationModal';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Select, Switch, Avatar, Upload, Tooltip } from 'antd';
import { UserOutlined, EditOutlined, UploadOutlined, FilterOutlined, EnvironmentOutlined } from '@ant-design/icons';
import { Grid } from 'antd';
import styles from './style.module.scss';
import { getUsers, createUser, updateUser, deleteUser, changeUserPassword, getRoles, getGroups, updateUserAvatar, updateUserStatus } from '../../../../axios/api/account';
import { MapContainer, TileLayer, Marker, useMap, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';

// Fix leaflet default marker icon
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

// Set view on edit (used for view only here too)
const SetViewOnEdit = ({ lat, lng }) => {
    const map = useMap();
    useEffect(() => {
        const parsedLat = parseFloat(lat);
        const parsedLng = parseFloat(lng);
        if (!isNaN(parsedLat) && !isNaN(parsedLng)) {
            map.setView([parsedLat, parsedLng], 15);
        }
    }, [lat, lng, map]);
    return null;
};

// Fix map rendering in modal
const MapResizer = () => {
    const map = useMap();
    useEffect(() => {
        const timer = setTimeout(() => {
            map.invalidateSize();
        }, 100);
        return () => clearTimeout(timer);
    }, [map]);
    return null;
};
import { useAuth } from '../../../../context/AuthContext';
import { handleApiError } from '../../../../utils/errorHandler';

const UserTab = ({ isActive }) => {
    const { user: currentUser, refetchUser } = useAuth();
    const [data, setData] = useState([]);
    const [roles, setRoles] = useState([]);
    const [groups, setGroups] = useState([]);
    const [loading, setLoading] = useState(false);

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [roleFilter, setRoleFilter] = useState(null);
    const [groupFilter, setGroupFilter] = useState(null);
    const [statusFilter, setStatusFilter] = useState('all'); // 'all' = hamısı, true = aktiv, false = deaktiv
    const [showFilters, setShowFilters] = useState(false);
    const screens = Grid.useBreakpoint();

    const [isModalOpen, setIsModalOpen] = useState(false);
    const [isPasswordModalOpen, setIsPasswordModalOpen] = useState(false);
    const [isMapModalOpen, setIsMapModalOpen] = useState(false);

    // New Live Map Modal State
    const [isLiveMapModalOpen, setIsLiveMapModalOpen] = useState(false);
    const [liveMapUserId, setLiveMapUserId] = useState(null);

    const [editingItem, setEditingItem] = useState(null);
    const [viewingCoords, setViewingCoords] = useState(null);
    const [form] = Form.useForm();
    const [passwordForm] = Form.useForm();

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
            const usersRes = await getUsers();
            setData(usersRes.data);

            const rolesRes = await getRoles();
            setRoles(rolesRes.data);

            const groupsRes = await getGroups();
            setGroups(groupsRes.data);
        } catch (error) {
            console.error(error);
            handleApiError(error, 'İstifadəçiləri yükləmək mümkün olmadı');
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
            await deleteUser(id);
            message.success('İstifadəçi silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    const onFinish = async (values) => {
        try {
            if (editingItem) {
                await updateUser(editingItem.id, values);
                message.success('İstifadəçi yeniləndi');
            } else {
                await createUser(values);
                message.success('İstifadəçi yaradıldı');
            }
            setIsModalOpen(false);
            form.resetFields();
            setEditingItem(null);
            fetchData();
        } catch (error) {
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        }
    };

    const onPasswordFinish = async (values) => {
        try {
            await changeUserPassword(editingItem.id, values);
            message.success('Şifrə dəyişdirildi');
            setIsPasswordModalOpen(false);
            passwordForm.resetFields();
            setEditingItem(null);
        } catch (error) {
            handleApiError(error, 'Şifrə dəyişimi uğursuz oldu');
        }
    }

    const openMapModal = (record) => {
        if (record.address_coordinates && record.address_coordinates.lat) {
            setViewingCoords(record.address_coordinates);
            setIsMapModalOpen(true);
        } else {
            message.info('Bu istifadəçinin ünvanı yoxdur');
        }
    };

    const getFilteredData = () => {
        return data.filter(item => {
            // Search
            const lowerSearch = debouncedSearchText.toLowerCase();
            const matchesSearch =
                item.username.toLowerCase().includes(lowerSearch) ||
                item.email.toLowerCase().includes(lowerSearch) ||
                (item.first_name && item.first_name.toLowerCase().includes(lowerSearch)) ||
                (item.last_name && item.last_name.toLowerCase().includes(lowerSearch));

            // Filters
            const matchesRole = roleFilter ? item.role_name === roleFilter : true;
            const matchesGroup = groupFilter ? item.group_name === groupFilter : true;
            const matchesStatus = statusFilter !== 'all' ? item.is_active === statusFilter : true;

            return matchesSearch && matchesRole && matchesGroup && matchesStatus;
        });
    };

    const handleAvatarUpload = async (file, userId) => {
        const formData = new FormData();
        formData.append('avatar', file);
        try {
            await updateUserAvatar(userId, formData);
            message.success('Avatar yeniləndi');
            fetchData();
            // If the updated user is the current logged-in user, refresh header
            if (currentUser && currentUser.id === userId) {
                refetchUser();
            }
        } catch (error) {
            handleApiError(error, 'Avatar yenilənmədi');
        }
        return false; // Prevent auto upload
    };

    const handleStatusChange = async (id, checked) => {
        try {
            await updateUserStatus(id, checked);
            message.success('Status yeniləndi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id' },
        {
            title: 'Avatar',
            key: 'avatar',
            render: (_, record) => (
                <div className={styles.avatarContainer}>
                    <Avatar
                        src={record.avatar}
                        icon={!record.avatar && <UserOutlined />}
                        size={40}
                    />
                    <div className={styles.avatarOverlay}>
                        <Upload
                            showUploadList={false}
                            beforeUpload={(file) => handleAvatarUpload(file, record.id)}
                        >
                            <EditOutlined className={styles.editIcon} />
                        </Upload>
                    </div>
                </div>
            )
        },
        { title: 'İstifadəçi adı', dataIndex: 'username', key: 'username' },
        { title: 'Email', dataIndex: 'email', key: 'email' },
        { title: 'Telefon', dataIndex: 'phone_number', key: 'phone_number' },
        { title: 'Rol', dataIndex: 'role_name', key: 'role_name' },
        { title: 'Qrup', dataIndex: 'group_name', key: 'group_name' },
        {
            title: 'Unvan',
            key: 'map',
            width: 80,
            render: (_, record) => (
                <EnvironmentOutlined
                    style={{
                        fontSize: 18,
                        cursor: record.address_coordinates?.lat ? 'pointer' : 'default',
                        color: record.address_coordinates?.lat ? '#1890ff' : '#ccc'
                    }}
                    onClick={() => {
                        // Open advanced map modal
                        setLiveMapUserId(record.id);
                        setIsLiveMapModalOpen(true);
                    }}
                />
            )
        },
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
            title: 'Əməliyyatlar',
            key: 'action',
            render: (_, record) => (
                <>
                    <Button type="link" onClick={() => {
                        setEditingItem(record);
                        form.setFieldsValue(record);
                        setIsModalOpen(true);
                    }}>Düzəliş</Button>
                    <Button type="link" onClick={() => {
                        setEditingItem(record);
                        setIsPasswordModalOpen(true);
                    }}>Şifrə</Button>
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
                    alignItems: screens.md ? 'center' : 'stretch', // Stretch on mobile for full width
                    gap: '8px'
                }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', width: screens.md ? 'auto' : '100%' }}>
                        <Input.Search
                            placeholder="Axtar (Ad, Email)..."
                            onChange={(e) => setSearchText(e.target.value)}
                            style={{ width: screens.md ? 250 : '100%' }} // Full width on mobile
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
                        flexDirection: screens.md ? 'row' : 'column', // Stack on mobile
                        gap: '8px',
                        flexWrap: 'wrap',
                        alignItems: screens.md ? 'center' : 'stretch', // Stretch on mobile
                        width: screens.md ? 'auto' : '100%'
                    }}>
                        {/* Filters Conditionally Hidden on Mobile */}
                        {(screens.md || showFilters) && (
                            <>
                                <Select
                                    placeholder="Rol seçin"
                                    style={{ width: screens.md ? 150 : '100%' }} // Full width on mobile
                                    allowClear
                                    onChange={setRoleFilter}
                                >
                                    {roles.map(r => <Select.Option key={r.id} value={r.name}>{r.name}</Select.Option>)}
                                </Select>
                                <Select
                                    placeholder="Qrup seçin"
                                    style={{ width: screens.md ? 150 : '100%' }} // Full width on mobile
                                    allowClear
                                    onChange={setGroupFilter}
                                >
                                    {groups.map(g => <Select.Option key={g.id} value={g.name}>{g.name}</Select.Option>)}
                                </Select>
                                <Select
                                    placeholder="Status"
                                    style={{ width: screens.md ? 150 : '100%' }} // Full width on mobile
                                    value={statusFilter}
                                    onChange={setStatusFilter}
                                >
                                    <Select.Option value="all">Hamısı</Select.Option>
                                    <Select.Option value={true}>Aktiv</Select.Option>
                                    <Select.Option value={false}>Deaktiv</Select.Option>
                                </Select>
                            </>
                        )}
                        <Button type="primary" block={!screens.md} onClick={() => {
                            setEditingItem(null);
                            form.resetFields();
                            setIsModalOpen(true);
                        }}>
                            Yeni İstifadəçi
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
                title={editingItem ? "İstifadəçiyə Düzəliş" : "Yeni İstifadəçi"}
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                footer={null}
                className={styles.userModal}
            >
                <Form form={form} onFinish={onFinish} layout="vertical">
                    <Form.Item name="username" label="İstifadəçi adı" rules={[{ required: true }]}>
                        <Input />
                    </Form.Item>
                    <Form.Item name="email" label="Email" rules={[{ required: true, type: 'email' }]}>
                        <Input />
                    </Form.Item>
                    <Form.Item name="phone_number" label="Telefon Nömrəsi">
                        <Input />
                    </Form.Item>
                    {/* Password is only for CREATE, separate functionality for change password exists */}
                    {!editingItem && (
                        <Form.Item
                            name="password"
                            label="Şifrə"
                            rules={[{ required: true, message: 'Şifrə mütləqdir' }]}
                        >
                            <Input.Password />
                        </Form.Item>
                    )}
                    <Form.Item name="first_name" label="Ad">
                        <Input />
                    </Form.Item>
                    <Form.Item name="last_name" label="Soyad">
                        <Input />
                    </Form.Item>
                    <Form.Item name="role" label="Rol">
                        <Select>
                            {roles.map(r => (
                                <Select.Option key={r.id} value={r.id}>{r.name}</Select.Option>
                            ))}
                        </Select>
                    </Form.Item>
                    <Form.Item name="group" label="Qrup">
                        <Select>
                            {groups.map(g => (
                                <Select.Option key={g.id} value={g.id}>{g.name}</Select.Option>
                            ))}
                        </Select>
                    </Form.Item>
                    {/* Only show Active switch on creation, or if you want to allow changing active status only here? title said 'user edit edende password ve aktivliyini deyismek olmasin' */}
                    {!editingItem && (
                        <Form.Item name="is_active" label="Aktiv" valuePropName="checked">
                            <Switch />
                        </Form.Item>
                    )}
                    <Button type="primary" htmlType="submit" block>
                        Təsdiqlə
                    </Button>
                </Form>
            </Modal>

            <Modal
                title="Şifrəni Dəyiş"
                open={isPasswordModalOpen}
                onCancel={() => setIsPasswordModalOpen(false)}
                footer={null}
                className={styles.userModal}
            >
                <Form form={passwordForm} onFinish={onPasswordFinish} layout="vertical">
                    <Form.Item name="password" label="Yeni Şifrə" rules={[{ required: true }]}>
                        <Input.Password />
                    </Form.Item>
                    <Button type="primary" htmlType="submit" block>
                        Yenilə
                    </Button>
                </Form>
            </Modal>

            <Modal
                title="Ünvan"
                open={isMapModalOpen}
                onCancel={() => setIsMapModalOpen(false)}
                footer={null}
                width={700}
                destroyOnClose
            >
                <div style={{ height: '400px', width: '100%' }}>
                    <MapContainer
                        center={viewingCoords ? [viewingCoords.lat, viewingCoords.lng] : [40.4093, 49.8671]}
                        zoom={15}
                        style={{ height: '100%', width: '100%' }}
                    >
                        <TileLayer
                            attribution='&copy; OpenStreetMap contributors'
                            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                        />
                        <MapResizer />
                        {viewingCoords && (
                            <>
                                <Marker position={[viewingCoords.lat, viewingCoords.lng]} />
                                <SetViewOnEdit lat={viewingCoords.lat} lng={viewingCoords.lng} />
                            </>
                        )}
                    </MapContainer>
                </div>
            </Modal>

            <UserLocationModal
                open={isLiveMapModalOpen}
                onCancel={() => setIsLiveMapModalOpen(false)}
                userId={liveMapUserId}
            />
        </div >
    );
};

export default UserTab;
