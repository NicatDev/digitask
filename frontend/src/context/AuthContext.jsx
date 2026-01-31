import React, { createContext, useState, useEffect, useContext } from 'react';
import { getMe } from '../axios/api/account';
import { message } from 'antd';
import { useNavigate } from 'react-router-dom';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);
    const navigate = useNavigate();

    const fetchUser = async (redirectOnError = false) => {
        setLoading(true);
        try {
            const token = localStorage.getItem('access_token');
            if (token) {
                const response = await getMe();
                setUser(response.data);
            } else {
                setUser(null);
                if (redirectOnError) navigate('/login');
            }
        } catch (error) {
            console.error('Fetch user failed', error);
            setUser(null);
            // If token invalid, maybe clear it?
            // localStorage.removeItem('access_token');
            if (redirectOnError) navigate('/login');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchUser();
    }, []);

    const login = (token) => {
        localStorage.setItem('access_token', token);
        fetchUser(true); // Fetch user immediately after setting token
    };

    const logout = () => {
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        setUser(null);
        navigate('/login');
    };

    const refetchUser = () => {
        fetchUser();
    };

    return (
        <AuthContext.Provider value={{ user, loading, login, logout, refetchUser }}>
            {children}
        </AuthContext.Provider>
    );
};

export const useAuth = () => useContext(AuthContext);
