import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import { hasPermission } from '../../utils/permissions';
import { Button, Result } from 'antd';

const ProtectedRoute = ({ children, requiredPermissions, requireAll = false }) => {
    const { user, loading } = useAuth();
    const location = useLocation();

    if (loading) {
        return <div>Loading...</div>; // Or a proper spinner
    }

    if (!user) {
        return <Navigate to="/login" state={{ from: location }} replace />;
    }

    if (requiredPermissions) {
        const canAccess = hasPermission(user, requiredPermissions, requireAll);

        if (!canAccess) {
            return (
                <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
                    <Result
                        status="403"
                        title="403"
                        subTitle="Bu səhifəyə giriş icazəniz yoxdur."
                        extra={<Button type="primary" href="/">Ana Səhifəyə Qayıt</Button>}
                    />
                </div>
            );
        }
    }

    return children;
};

export default ProtectedRoute;
