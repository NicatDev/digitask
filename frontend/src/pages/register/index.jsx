import React, { useState } from 'react';
import { Form, Button, Card, Typography, message, Checkbox } from 'antd';
import { Link, useNavigate } from 'react-router-dom';
import styles from '../login/style.module.scss';

const { Title, Text, Paragraph } = Typography;

const Register = () => {
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

    const onFinish = async () => {
        setLoading(true);
        try {
            message.info(
                'Hesabların yaradılması administrator tərəfindən həyata keçirilir. Təşkilatınızın meneceri ilə əlaqə saxlayın.',
                5,
            );
            navigate('/login');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className={styles.loginPage}>
            <Card className={styles.loginCard} bordered={false}>
                <div className={styles.loginHeader}>
                    <Title level={3}>Qeydiyyat</Title>
                    <Paragraph type="secondary" style={{ marginBottom: 0 }}>
                        Platformadan istifadə üçün məxfilik siyasəti və istifadə şərtləri ilə
                        tanış olmalı və qəbulu təsdiqləməlisiniz. Yeni işçi hesabları təşkilat
                        administratoru tərəfindən aktivləşdirilir.
                    </Paragraph>
                </div>
                <Form
                    name="register_form"
                    className={styles.loginForm}
                    onFinish={onFinish}
                    size="large"
                    layout="vertical"
                    requiredMark={false}
                >
                    <Form.Item
                        name="acceptTerms"
                        valuePropName="checked"
                        rules={[
                            {
                                validator: (_, value) =>
                                    value
                                        ? Promise.resolve()
                                        : Promise.reject(
                                              new Error(
                                                  'Davam etmək üçün məxfilik siyasəti və istifadə şərtlərini qəbul edin.',
                                              ),
                                          ),
                            },
                        ]}
                    >
                        <Checkbox>
                            <Link to="/privacy-policy" target="_blank" rel="noopener noreferrer">
                                Məxfilik siyasəti
                            </Link>
                            {' və '}
                            <Link to="/terms-conditions" target="_blank" rel="noopener noreferrer">
                                İstifadə şərtləri
                            </Link>
                            ilə tanış oldum və razıyam.
                        </Checkbox>
                    </Form.Item>

                    <Form.Item>
                        <Button
                            type="primary"
                            htmlType="submit"
                            className={styles.loginFormButton}
                            loading={loading}
                            block
                        >
                            Təsdiq edirəm
                        </Button>
                    </Form.Item>
                </Form>
                <div style={{ textAlign: 'center' }}>
                    <Text type="secondary">Artıq hesabınız var? </Text>
                    <Link to="/login">Daxil ol</Link>
                </div>
            </Card>
        </div>
    );
};

export default Register;
