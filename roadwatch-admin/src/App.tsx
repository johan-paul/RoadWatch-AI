import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './contexts/AuthContext'
import { Layout } from './components/Layout'
import { LoginPage } from './pages/LoginPage'
import { DashboardPage } from './pages/DashboardPage'
import { ComplaintsPage } from './pages/ComplaintsPage'
import { ComplaintDetailPage } from './pages/ComplaintDetailPage'
import { OfficersPage } from './pages/OfficersPage'
import { CitizensPage } from './pages/CitizensPage'
import { AuditLogsPage } from './pages/AuditLogsPage'
import { MapPage } from './pages/MapPage'
import { BudgetPage } from './pages/BudgetPage'
import { PriorityPage } from './pages/PriorityPage'

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuth()
  return isAuthenticated ? <>{children}</> : <Navigate to="/login" replace />
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        element={
          <ProtectedRoute>
            <Layout />
          </ProtectedRoute>
        }
      >
        <Route path="/"            element={<DashboardPage />} />
        <Route path="/complaints"  element={<ComplaintsPage />} />
        <Route path="/complaints/:id" element={<ComplaintDetailPage />} />
        <Route path="/priority"    element={<PriorityPage />} />
        <Route path="/officers"    element={<OfficersPage />} />
        <Route path="/citizens"    element={<CitizensPage />} />
        <Route path="/budget"      element={<BudgetPage />} />
        <Route path="/audit"       element={<AuditLogsPage />} />
        <Route path="/map"         element={<MapPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <AppRoutes />
      </BrowserRouter>
    </AuthProvider>
  )
}
