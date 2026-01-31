import React, { useState } from 'react';
import { Form, Input, Button, Card, Typography, message } from 'antd';
import { UserOutlined, LockOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import styles from './style.module.scss';
import { useAuth } from '../../context/AuthContext';
import { loginUser } from '../../axios/api/account';
import { handleApiError } from '../../utils/errorHandler';

const { Title } = Typography;

const Login = () => {
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();
    const { login } = useAuth();

    const onFinish = async (values) => {
        setLoading(true);
        try {
            const response = await loginUser({
                username: values.username,
                password: values.password,
            });

            login(response.data.access);
            localStorage.setItem('refresh_token', response.data.refresh);
            message.success('Giriş uğurludur!');
            navigate('/users');

        } catch (error) {
            console.error(error);
            handleApiError(error, 'Giriş uğursuz oldu');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className={styles.loginPage}>
            <Card className={styles.loginCard} bordered={false}>
                <div className={styles.loginHeader}>
                    <Title level={3}>Xoş Gəlmisiniz</Title>
                    <p>Davam etmək üçün giriş edin</p>
                </div>
                <Form
                    name="login_form"
                    className={styles.loginForm}
                    initialValues={{ remember: true }}
                    onFinish={onFinish}
                    size="large"
                    layout="vertical"
                >
                    <Form.Item
                        name="username"
                        rules={[{ required: true, message: 'İstifadəçi adı daxil edin!' }]}
                    >
                        <Input prefix={<UserOutlined />} placeholder="İstifadəçi adı" />
                    </Form.Item>
                    <Form.Item
                        name="password"
                        rules={[{ required: true, message: 'Şifrə daxil edin!' }]}
                    >
                        <Input.Password prefix={<LockOutlined />} placeholder="Şifrə" />
                    </Form.Item>

                    <Form.Item>
                        <Button type="primary" htmlType="submit" className={styles.loginFormButton} loading={loading} block>
                            Daxil ol
                        </Button>
                    </Form.Item>
                </Form>
            </Card>
        </div>
    );
};

export default Login;
