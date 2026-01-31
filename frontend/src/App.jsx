import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/login';
import MainLayout from './components/layout/MainLayout';
import UsersPage from './pages/users';
import WarehousePage from './pages/warehouse';
import AdminPage from './pages/admin';
import TasksPage from './pages/tasks';
import { AuthProvider } from './context/AuthContext';

const App = () => {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route element={<MainLayout />}>
            <Route path="/users" element={<UsersPage />} />
            <Route path="/warehouse" element={<WarehousePage />} />
            <Route path="/admin" element={<AdminPage />} />
            <Route path="/tasks" element={<TasksPage />} />
            <Route path="/" element={<Navigate to="/tasks" replace />} />
          </Route>
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
};

export default App;

