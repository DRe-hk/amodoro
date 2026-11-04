import type { Metadata } from "next";
import AdminDashboardClient from "./admin-client";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "amodoro · Admin Dashboard",
  description: "Panel de administración privado de amodoro.",
  robots: {
    index: false,
    follow: false,
  },
};

export default function AdminPage() {
  return <AdminDashboardClient />;
}
