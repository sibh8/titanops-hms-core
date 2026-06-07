import { Routes, Route } from 'react-router-dom';
import AppLayout from './components/AppLayout';
import LoginPage from './pages/LoginPage';
import RegisterPage from './pages/RegisterPage';
import DashboardPage from './pages/DashboardPage';
// Patients
import PatientListPage from './pages/patients/PatientListPage';
import PatientFormPage from './pages/patients/PatientFormPage';
import PatientViewPage from './pages/patients/PatientViewPage';
// Appointments
import AppointmentListPage from './pages/appointments/AppointmentListPage';
import AppointmentFormPage from './pages/appointments/AppointmentFormPage';
import AppointmentViewPage from './pages/appointments/AppointmentViewPage';
// Providers
import ProviderListPage from './pages/providers/ProviderListPage';
import ProviderFormPage from './pages/providers/ProviderFormPage';
// Users
import UserListPage from './pages/users/UserListPage';
import UserFormPage from './pages/users/UserFormPage';
// Lab
import LabListPage      from './pages/lab/LabListPage';
import LabOrderFormPage from './pages/lab/LabOrderFormPage';
import LabOrderViewPage from './pages/lab/LabOrderViewPage';
// Billing
import BillingListPage  from './pages/billing/BillingListPage';
import InvoiceFormPage  from './pages/billing/InvoiceFormPage';
import InvoiceViewPage  from './pages/billing/InvoiceViewPage';
// Encounters
import EncounterListPage from './pages/encounters/EncounterListPage';
import EncounterViewPage from './pages/encounters/EncounterViewPage';
// Medications
import MedicationListPage from './pages/medications/MedicationListPage';
import MedicationFormPage from './pages/medications/MedicationFormPage';
// Prescriptions
import PrescriptionListPage from './pages/prescriptions/PrescriptionListPage';
import PrescriptionFormPage from './pages/prescriptions/PrescriptionFormPage';
import PrescriptionViewPage from './pages/prescriptions/PrescriptionViewPage';
// System
import ServiceStatusPage from './pages/ServiceStatusPage';

export default function App() {
  return (
    <Routes>
      <Route path="/login"    element={<LoginPage />} />
      <Route path="/register" element={<RegisterPage />} />
      <Route element={<AppLayout />}>
        <Route index element={<DashboardPage />} />

        {/* Patients */}
        <Route path="patients"          element={<PatientListPage />} />
        <Route path="patients/new"      element={<PatientFormPage />} />
        <Route path="patients/:id"      element={<PatientViewPage />} />
        <Route path="patients/:id/edit" element={<PatientFormPage />} />

        {/* Appointments */}
        <Route path="appointments"          element={<AppointmentListPage />} />
        <Route path="appointments/new"      element={<AppointmentFormPage />} />
        <Route path="appointments/:id"      element={<AppointmentViewPage />} />
        <Route path="appointments/:id/edit" element={<AppointmentFormPage />} />

        {/* Providers */}
        <Route path="providers"          element={<ProviderListPage />} />
        <Route path="providers/new"      element={<ProviderFormPage />} />
        <Route path="providers/:id/edit" element={<ProviderFormPage />} />

        {/* Users */}
        <Route path="users"          element={<UserListPage />} />
        <Route path="users/new"      element={<UserFormPage />} />
        <Route path="users/:id/edit" element={<UserFormPage />} />

        {/* Lab */}
        <Route path="lab"      element={<LabListPage />} />
        <Route path="lab/new"  element={<LabOrderFormPage />} />
        <Route path="lab/:id"  element={<LabOrderViewPage />} />

        {/* Billing */}
        <Route path="billing"          element={<BillingListPage />} />
        <Route path="billing/new"      element={<InvoiceFormPage />} />
        <Route path="billing/:id"      element={<InvoiceViewPage />} />
        <Route path="billing/:id/edit" element={<InvoiceFormPage />} />

        {/* Encounters */}
        <Route path="encounters"     element={<EncounterListPage />} />
        <Route path="encounters/:id" element={<EncounterViewPage />} />

        {/* Medications */}
        <Route path="medications"          element={<MedicationListPage />} />
        <Route path="medications/new"      element={<MedicationFormPage />} />
        <Route path="medications/:id/edit" element={<MedicationFormPage />} />

        {/* Prescriptions */}
        <Route path="prescriptions"     element={<PrescriptionListPage />} />
        <Route path="prescriptions/new" element={<PrescriptionFormPage />} />
        <Route path="prescriptions/:id" element={<PrescriptionViewPage />} />

        {/* System */}
        <Route path="status" element={<ServiceStatusPage />} />
      </Route>
    </Routes>
  );
}
