// send-notification-email Edge Function
// v1.3 M21: pg_net trigger → 이 함수 호출 → 이메일 발송
// Design: §9

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SMTP_HOST = Deno.env.get("SMTP_HOST");
const SMTP_FROM = Deno.env.get("SMTP_FROM") ?? "noreply@rigel.app";

interface NotificationRow {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string | null;
  document_id: string;
}

interface ProfileRow {
  id: string;
  email: string;
  display_name: string;
}

const EMAIL_SUBJECT: Record<string, string> = {
  approval_requested: "[Rigel] 결재 요청이 도착했습니다",
  approved: "[Rigel] 결재가 완료되었습니다",
  rejected: "[Rigel] 문서가 반려되었습니다",
  commented: "[Rigel] 새 코멘트가 등록되었습니다",
  withdrawn: "[Rigel] 문서가 회수되었습니다",
};

Deno.serve(async (req) => {
  try {
    const { document_id, tenant_id, action } = await req.json();

    if (!document_id || !tenant_id) {
      return new Response(JSON.stringify({ error: "missing params" }), {
        status: 400,
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 이 document + tenant 의 최근 미발송 notifications 조회
    const { data: notifications } = await supabase
      .from("notifications")
      .select("id, user_id, type, title, body, document_id")
      .eq("document_id", document_id)
      .eq("tenant_id", tenant_id)
      .eq("read", false)
      .order("created_at", { ascending: false })
      .limit(20);

    if (!notifications || notifications.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    // 수신자 프로필 조회
    const userIds = [...new Set(notifications.map((n: NotificationRow) => n.user_id))];
    const { data: profiles } = await supabase
      .from("profiles")
      .select("id, email, display_name")
      .in("id", userIds);

    const profileMap = new Map<string, ProfileRow>();
    for (const p of profiles ?? []) {
      profileMap.set(p.id, p as ProfileRow);
    }

    // SMTP 미설정 → console fallback (dev mode)
    if (!SMTP_HOST) {
      for (const n of notifications as NotificationRow[]) {
        const profile = profileMap.get(n.user_id);
        console.log(
          `[email-fallback] to=${profile?.email ?? n.user_id} subject="${EMAIL_SUBJECT[n.type] ?? n.title}" body="${n.body ?? ""}"`,
        );
      }
      return new Response(
        JSON.stringify({ sent: notifications.length, mode: "console" }),
        { status: 200 },
      );
    }

    // TODO: 실제 SMTP 발송 구현 (Resend/SendGrid API)
    // 현재는 console fallback만 지원. 프로덕션 배포 시 SMTP_HOST 설정 후 구현.
    let sentCount = 0;
    for (const n of notifications as NotificationRow[]) {
      const profile = profileMap.get(n.user_id);
      if (!profile?.email) continue;

      console.log(
        `[email] to=${profile.email} subject="${EMAIL_SUBJECT[n.type] ?? n.title}"`,
      );
      sentCount++;
    }

    return new Response(JSON.stringify({ sent: sentCount }), { status: 200 });
  } catch (err) {
    console.error("[send-notification-email] error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
    });
  }
});
