import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/login';
import MainLayout from './components/layout/MainLayout';
import UsersPage from './pages/users';
import WarehousePage from './pages/warehouse';
import AdminPage from './pages/admin';
import TasksPage from './pages/tasks';
import ChatPage from './pages/chat';
import LiveMap from './pages/live-map';
import NotificationsPage from './pages/notifications';
import { AuthProvider } from './context/AuthContext';
import { NotificationProvider } from './context/NotificationContext';

const App = () => {
  return (
    <BrowserRouter>
      <AuthProvider>
        <NotificationProvider>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route element={<MainLayout />}>
              <Route path="/tasks" element={<TasksPage />} />
              <Route path="/users" element={<UsersPage />} />
              <Route path="/warehouse" element={<WarehousePage />} />
              <Route path="/admin" element={<AdminPage />} />
              <Route path="/chat" element={<ChatPage />} />
              <Route path="/map" element={<LiveMap />} />
              <Route path="/notifications" element={<NotificationsPage />} />
              <Route path="/" element={<Navigate to="/tasks" replace />} />
            </Route>
          </Routes>
        </NotificationProvider>
      </AuthProvider>
    </BrowserRouter>
  );
};

export default App;
