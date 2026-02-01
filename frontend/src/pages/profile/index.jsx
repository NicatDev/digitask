import React, { useState, useEffect } from 'react';
import { Card, Avatar, Upload, Button, Input, Form, message, Spin, Divider, Modal } from 'antd';
import { UserOutlined, EditOutlined, CameraOutlined, LockOutlined, CheckOutlined, CloseOutlined } from '@ant-design/icons';
import { getMe, updateMyProfile, updateMyAvatar, changeMyPassword } from '../../axios/api/account';
import { handleApiError } from '../../utils/errorHandler';
import styles from './style.module.scss';

const Profile = () => {
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);
    const [avatarUploading, setAvatarUploading] = useState(false);

    // Editable fields state
    const [editingField, setEditingField] = useState(null);
    const [editValue, setEditValue] = useState('');
    const [saving, setSaving] = useState(false);

    // Password modal
    const [passwordModalOpen, setPasswordModalOpen] = useState(false);
    const [passwordForm] = Form.useForm();
    const [changingPassword, setChangingPassword] = useState(false);

    const fetchUser = async () => {
        setLoading(true);
        try {
            const res = await getMe();
            setUser(res.data);
        } catch (error) {
            handleApiError(error, 'Profil yüklənmədi');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchUser();
    }, []);

    // Avatar upload
    const handleAvatarUpload = async (info) => {
        const file = info.file;
        if (!file) return;

        setAvatarUploading(true);
        try {
            const formData = new FormData();
            formData.append('avatar', file);
            await updateMyAvatar(formData);
            message.success('Avatar yeniləndi');
            fetchUser();
        } catch (error) {
            handleApiError(error, 'Avatar yenilənmədi');
        } finally {
            setAvatarUploading(false);
        }
    };

    // Start editing field
    const startEdit = (field, currentValue) => {
        setEditingField(field);
        setEditValue(currentValue || '');
    };

    // Cancel editing
    const cancelEdit = () => {
        setEditingField(null);
        setEditValue('');
    };

    // Save field
    const saveField = async (field) => {
        setSaving(true);
        try {
            await updateMyProfile({ [field]: editValue });
            message.success('Məlumat yeniləndi');
            setEditingField(null);
            fetchUser();
        } catch (error) {
            handleApiError(error, 'Yeniləmə uğursuz oldu');
        } finally {
            setSaving(false);
        }
    };

    // Change password
    const handlePasswordChange = async (values) => {
        if (values.new_password !== values.confirm_password) {
            message.error('Parollar uyğun gəlmir');
            return;
        }

        setChangingPassword(true);
        try {
            await changeMyPassword({
                old_password: values.old_password,
                new_password: values.new_password
            });
            message.success('Parol uğurla dəyişdirildi');
            setPasswordModalOpen(false);
            passwordForm.resetFields();
        } catch (error) {
            handleApiError(error, 'Parol dəyişdirilmədi');
        } finally {
            setChangingPassword(false);
        }
    };

    const editableFields = [
        { key: 'first_name', label: 'Ad' },
        { key: 'last_name', label: 'Soyad' },
        { key: 'email', label: 'Email' },
        { key: 'phone_number', label: 'Telefon' },
    ];

    const renderEditableField = (field) => {
        const isEditing = editingField === field.key;
        const value = user?.[field.key] || '';

        return (
            <div key={field.key} className={styles.fieldRow}>
                <div className={styles.fieldLabel}>{field.label}</div>
                <div className={styles.fieldValue}>
                    {isEditing ? (
                        <div className={styles.editingWrapper}>
                            <Input
                                value={editValue}
                                onChange={(e) => setEditValue(e.target.value)}
                                onPressEnter={() => saveField(field.key)}
                                autoFocus
                            />
                            <Button
                                type="primary"
                                icon={<CheckOutlined />}
                                onClick={() => saveField(field.key)}
                                loading={saving}
                                size="small"
                            />
                            <Button
                                icon={<CloseOutlined />}
                                onClick={cancelEdit}
                                size="small"
                            />
                        </div>
                    ) : (
                        <div className={styles.valueWrapper}>
                            <span>{value || '-'}</span>
                            <Button
                                type="text"
                                icon={<EditOutlined />}
                                onClick={() => startEdit(field.key, value)}
                                className={styles.editButton}
                            />
                        </div>
                    )}
                </div>
            </div>
        );
    };

    if (loading) {
        return (
            <div className={styles.loadingContainer}>
                <Spin size="large" />
            </div>
        );
    }

    return (
        <div className={styles.profilePage}>
            <h1>Profil</h1>

            <div className={styles.profileContent}>
                {/* Avatar Section */}
                <Card className={styles.avatarCard}>
                    <div className={styles.avatarSection}>
                        <div className={styles.avatarWrapper}>
                            <Avatar
                                size={120}
                                src={user?.avatar}
                                icon={<UserOutlined />}
                            />
                            <Upload
                                showUploadList={false}
                                beforeUpload={() => false}
                                onChange={handleAvatarUpload}
                                accept="image/*"
                            >
                                <Button
                                    className={styles.avatarUploadBtn}
                                    icon={<CameraOutlined />}
                                    loading={avatarUploading}
                                    shape="circle"
                                />
                            </Upload>
                        </div>
                        <div className={styles.userName}>
                            {user?.first_name} {user?.last_name}
                        </div>
                        <div className={styles.userRole}>
                            {user?.role_name || 'İstifadəçi'}
                        </div>
                    </div>
                </Card>

                {/* Profile Info Section */}
                <Card className={styles.infoCard} title="Şəxsi Məlumatlar">
                    {editableFields.map(renderEditableField)}

                    {/* Read-only fields */}
                    <div className={styles.fieldRow}>
                        <div className={styles.fieldLabel}>İstifadəçi adı</div>
                        <div className={styles.fieldValue}>
                            <span>{user?.username || '-'}</span>
                        </div>
                    </div>
                    <div className={styles.fieldRow}>
                        <div className={styles.fieldLabel}>Rol</div>
                        <div className={styles.fieldValue}>
                            <span>{user?.role_name || '-'}</span>
                        </div>
                    </div>
                    <div className={styles.fieldRow}>
                        <div className={styles.fieldLabel}>Qrup</div>
                        <div className={styles.fieldValue}>
                            <span>{user?.group_name || '-'}</span>
                        </div>
                    </div>

                    <Divider />

                    <Button
                        type="primary"
                        icon={<LockOutlined />}
                        onClick={() => setPasswordModalOpen(true)}
                    >
                        Parolu Dəyiş
                    </Button>
                </Card>
            </div>

            {/* Password Change Modal */}
            <Modal
                title="Parolu Dəyiş"
                open={passwordModalOpen}
                onCancel={() => {
                    setPasswordModalOpen(false);
                    passwordForm.resetFields();
                }}
                footer={null}
            >
                <Form form={passwordForm} layout="vertical" onFinish={handlePasswordChange}>
                    <Form.Item
                        name="old_password"
                        label="Köhnə Parol"
                        rules={[{ required: true, message: 'Köhnə parolu daxil edin' }]}
                    >
                        <Input.Password />
                    </Form.Item>
                    <Form.Item
                        name="new_password"
                        label="Yeni Parol"
                        rules={[
                            { required: true, message: 'Yeni parolu daxil edin' },
                            { min: 6, message: 'Parol minimum 6 simvol olmalıdır' }
                        ]}
                    >
                        <Input.Password />
                    </Form.Item>
                    <Form.Item
                        name="confirm_password"
                        label="Parolu Təsdiqlə"
                        dependencies={['new_password']}
                        rules={[
                            { required: true, message: 'Parolu təsdiqləyin' },
                            ({ getFieldValue }) => ({
                                validator(_, value) {
                                    if (!value || getFieldValue('new_password') === value) {
                                        return Promise.resolve();
                                    }
                                    return Promise.reject(new Error('Parollar uyğun gəlmir'));
                                },
                            }),
                        ]}
                    >
                        <Input.Password />
                    </Form.Item>
                    <Form.Item>
                        <Button type="primary" htmlType="submit" loading={changingPassword} block>
                            Parolu Dəyiş
                        </Button>
                    </Form.Item>
                </Form>
            </Modal>
        </div>
    );
};

export default Profile;
