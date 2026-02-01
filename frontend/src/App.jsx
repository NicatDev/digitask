import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/login';
import MainLayout from './components/layout/MainLayout';
import Dashboard from './pages/dashboard';
import UsersPage from './pages/users';
import WarehousePage from './pages/warehouse';
import AdminPage from './pages/admin';
import TasksPage from './pages/tasks';
import ChatPage from './pages/chat';
import LiveMap from './pages/live-map';
import NotificationsPage from './pages/notifications';
import DocumentsPage from './pages/documents';
import ProfilePage from './pages/profile';
import PerformancePage from './pages/performance';
import ProtectedRoute from './components/auth/ProtectedRoute';
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
              <Route path="/" element={<Dashboard />} />
              <Route path="/dashboard" element={<Navigate to="/" replace />} />
              <Route path="/performance" element={<PerformancePage />} />
              <Route
                path="/tasks"
                element={
                  <ProtectedRoute requiredPermissions={['is_task_reader', 'is_task_writer']}>
                    <TasksPage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/users"
                element={
                  <ProtectedRoute requiredPermissions={['is_admin', 'is_super_admin']}>
                    <UsersPage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/warehouse"
                element={
                  <ProtectedRoute requiredPermissions={['is_warehouse_reader', 'is_warehouse_writer']}>
                    <WarehousePage />
                  </ProtectedRoute>
                }
              />
              <Route
                path="/documents"
                element={
                  <ProtectedRoute requiredPermissions={['is_document_reader', 'is_document_writer']}>
                    <DocumentsPage />
                  </ProtectedRoute>
                }
              />
              <Route path="/profile" element={<ProfilePage />} />
              <Route
                path="/admin"
                element={
                  <ProtectedRoute requiredPermissions={['is_admin', 'is_super_admin']}>
                    <AdminPage />
                  </ProtectedRoute>
                }
              />
              <Route path="/chat" element={<ChatPage />} />
              <Route
                path="/map"
                element={
                  <ProtectedRoute requiredPermissions={['is_task_reader', 'is_task_writer']}>
                    <LiveMap />
                  </ProtectedRoute>
                }
              />
              <Route path="/notifications" element={<NotificationsPage />} />
              {/* <Route path="/" element={<Navigate to="/tasks" replace />} /> Replaced by Dashboard */}
            </Route>
          </Routes>
        </NotificationProvider>
      </AuthProvider>
    </BrowserRouter>
  );
};

export default App;
