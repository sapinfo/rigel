<script lang="ts">
  let installTab = $state<'prod' | 'dev'>('prod');
</script>

<div class="min-h-screen bg-white">
  <!-- Nav -->
  <nav class="sticky top-0 z-50 border-b bg-white/90 backdrop-blur">
    <div class="mx-auto max-w-6xl flex items-center justify-between px-6 py-3">
      <a href="/" class="text-xl font-bold text-blue-600">Rigel</a>
      <div class="flex items-center gap-6 text-sm">
        <a href="#features" class="text-gray-600 hover:text-gray-900">기능</a>
        <a href="#approval" class="text-gray-600 hover:text-gray-900">전자결재</a>
        <a href="#install" class="text-gray-600 hover:text-gray-900">설치</a>
        <a href="#support" class="text-gray-600 hover:text-gray-900">기술지원</a>
        <a href="/login" class="text-gray-600 hover:text-gray-900">로그인</a>
        <a href="/signup" class="rounded-lg bg-blue-600 px-4 py-2 text-white hover:bg-blue-700">데모 체험</a>
      </div>
    </div>
  </nav>

  <!-- Hero -->
  <section class="mx-auto max-w-6xl px-6 py-20 lg:py-28">
    <div class="max-w-3xl">
      <div class="inline-block rounded-full bg-blue-50 px-4 py-1.5 text-sm text-blue-700 mb-6">
        오픈소스 · 무료 · 셀프 호스팅
      </div>
      <h1 class="text-4xl font-bold tracking-tight lg:text-5xl leading-tight">
        한국식 전자결재,<br/>
        <span class="text-blue-600">미국에서도 그대로.</span>
      </h1>
      <p class="mt-6 text-lg text-gray-600 leading-relaxed">
        전결, 대결, 후결, 합의, 병렬결재 — 한국 본사와 동일한 결재 체계를<br class="hidden lg:block"/>
        우리 서버에 직접 설치해서 무료로 운영하세요.
      </p>
      <div class="mt-8 flex flex-wrap gap-3">
        <a href="https://github.com/sapinfo/rigel" class="rounded-lg bg-gray-900 px-6 py-3 text-sm font-medium text-white hover:bg-gray-800">
          GitHub에서 받기
        </a>
        <a href="/signup" class="rounded-lg border-2 border-blue-600 px-6 py-3 text-sm font-medium text-blue-600 hover:bg-blue-50">
          데모 사이트 체험
        </a>
      </div>
      <p class="mt-4 text-xs text-gray-400">서버 한 대 + Docker만 있으면 10분 안에 설치 완료</p>
    </div>
  </section>

  <!-- 핵심 가치 3칸 -->
  <section class="border-y bg-gray-50">
    <div class="mx-auto max-w-6xl px-6 py-12 grid grid-cols-1 gap-8 md:grid-cols-3">
      <div class="text-center">
        <div class="text-3xl mb-3">💰</div>
        <h3 class="font-bold">완전 무료</h3>
        <p class="mt-2 text-sm text-gray-600">오픈소스 라이선스. 사용자 수 제한 없음.<br/>월 구독료, 사용자당 과금 없음.</p>
      </div>
      <div class="text-center">
        <div class="text-3xl mb-3">🏢</div>
        <h3 class="font-bold">우리 서버에 설치</h3>
        <p class="mt-2 text-sm text-gray-600">데이터가 외부로 나가지 않음.<br/>사내 서버 또는 워크스테이션에 직접 운영.</p>
      </div>
      <div class="text-center">
        <div class="text-3xl mb-3">🇰🇷</div>
        <h3 class="font-bold">한국형 결재 완벽 지원</h3>
        <p class="mt-2 text-sm text-gray-600">미국 SaaS에는 없는 전결/대결/후결.<br/>한국 본사와 동일한 결재 프로세스.</p>
      </div>
    </div>
  </section>

  <!-- 기능 섹션 -->
  <section id="features" class="mx-auto max-w-6xl px-6 py-20">
    <div class="text-center mb-12">
      <h2 class="text-3xl font-bold">올인원 그룹웨어</h2>
      <p class="mt-3 text-gray-600">전자결재부터 게시판, 일정, 근태까지 하나로</p>
    </div>
    <div class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
      <div class="rounded-xl border p-6 hover:shadow-lg transition">
        <div class="text-2xl mb-3">📝</div>
        <h3 class="font-bold">전자결재</h3>
        <p class="mt-2 text-sm text-gray-600">양식 빌더로 기안서 자유 설계. 결재선 자동 구성, 즐겨찾기, 일괄 결재. PDF 출력과 전자서명까지.</p>
      </div>
      <div class="rounded-xl border p-6 hover:shadow-lg transition">
        <div class="text-2xl mb-3">💬</div>
        <h3 class="font-bold">게시판 & 공지</h3>
        <p class="mt-2 text-sm text-gray-600">전사/부서 게시판, 필독 공지 팝업, 읽음 확인. 리치 에디터로 첨부파일과 함께 작성.</p>
      </div>
      <div class="rounded-xl border p-6 hover:shadow-lg transition">
        <div class="text-2xl mb-3">📅</div>
        <h3 class="font-bold">일정 & 회의실</h3>
        <p class="mt-2 text-sm text-gray-600">개인/부서/전사 캘린더. 회의실 예약은 시간 겹침 자동 방지. 한눈에 보는 월간 뷰.</p>
      </div>
      <div class="rounded-xl border p-6 hover:shadow-lg transition">
        <div class="text-2xl mb-3">⏰</div>
        <h3 class="font-bold">근태관리</h3>
        <p class="mt-2 text-sm text-gray-600">원클릭 출퇴근. 지각 자동 판정. 월간 근태 리포트. 초과근무 신청은 결재로 연동.</p>
      </div>
      <div class="rounded-xl border p-6 hover:shadow-lg transition">
        <div class="text-2xl mb-3">🏗️</div>
        <h3 class="font-bold">조직도 & 인사</h3>
        <p class="mt-2 text-sm text-gray-600">부서 트리, 직급 체계, 프로필 관리. 조직도 기반 결재선 자동 구성의 기반.</p>
      </div>
      <div class="rounded-xl border p-6 hover:shadow-lg transition">
        <div class="text-2xl mb-3">🔔</div>
        <h3 class="font-bold">실시간 알림</h3>
        <p class="mt-2 text-sm text-gray-600">결재 요청, 승인, 반려를 실시간 알림. 놓치지 않는 결재 처리.</p>
      </div>
    </div>
  </section>

  <!-- 한국형 결재 차별화 -->
  <section id="approval" class="bg-gradient-to-br from-blue-600 to-indigo-700 text-white">
    <div class="mx-auto max-w-6xl px-6 py-20">
      <div class="text-center mb-12">
        <h2 class="text-3xl font-bold">미국 SaaS에는 없는 한국형 결재</h2>
        <p class="mt-3 text-blue-200">DocuSign, Monday.com으로는 절대 못 하는 것들</p>
      </div>
      <div class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
        <div class="rounded-xl bg-white/10 p-6">
          <h3 class="font-bold text-lg mb-2">전결</h3>
          <p class="text-sm text-blue-200">상위 결재자가 하위 단계를 건너뛰고 최종 승인. 위임 규칙으로 자동 적용.</p>
        </div>
        <div class="rounded-xl bg-white/10 p-6">
          <h3 class="font-bold text-lg mb-2">대결</h3>
          <p class="text-sm text-blue-200">결재자 부재 시 지정된 대리인이 대신 결재. 부재 등록과 자동 연동.</p>
        </div>
        <div class="rounded-xl bg-white/10 p-6">
          <h3 class="font-bold text-lg mb-2">후결</h3>
          <p class="text-sm text-blue-200">긴급 시 먼저 실행하고 나중에 결재. 사유 필수 입력, 감사 추적 완벽.</p>
        </div>
        <div class="rounded-xl bg-white/10 p-6">
          <h3 class="font-bold text-lg mb-2">합의</h3>
          <p class="text-sm text-blue-200">타 부서 의견 수렴 후 결재 진행. 동의/부동의 처리.</p>
        </div>
        <div class="rounded-xl bg-white/10 p-6">
          <h3 class="font-bold text-lg mb-2">병렬결재</h3>
          <p class="text-sm text-blue-200">같은 단계 여러 결재자가 동시 처리. 전원 승인 또는 과반 승인 설정.</p>
        </div>
        <div class="rounded-xl bg-white/10 p-6">
          <h3 class="font-bold text-lg mb-2">감사 추적</h3>
          <p class="text-sm text-blue-200">모든 결재 이력 타임라인 기록. PDF 출력, SHA-256 해시로 위변조 방지.</p>
        </div>
      </div>
    </div>
  </section>

  <!-- 설치 가이드 -->
  <section id="install" class="mx-auto max-w-6xl px-6 py-20">
    <div class="text-center mb-10">
      <h2 class="text-3xl font-bold">설치 가이드</h2>
      <p class="mt-3 text-gray-600">Docker만 설치되어 있으면 됩니다</p>
    </div>

    <div class="max-w-3xl mx-auto">
      <!-- 탭 -->
      <div class="flex border-b mb-8">
        <button type="button" class="px-5 py-2.5 text-sm font-medium border-b-2 {installTab === 'prod' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700'}" onclick={() => (installTab = 'prod')}>
          프로덕션 설치 (권장)
        </button>
        <button type="button" class="px-5 py-2.5 text-sm font-medium border-b-2 {installTab === 'dev' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700'}" onclick={() => (installTab = 'dev')}>
          개발 환경
        </button>
      </div>

      {#if installTab === 'prod'}
        <div class="mb-6 rounded-lg border-l-4 border-blue-500 bg-blue-50 p-4 text-sm text-gray-700">
          IT 전문 인력 없이도 설치 가능합니다. Docker가 설치된 서버/PC 한 대면 충분합니다.
        </div>
        <div class="mb-8 rounded-lg border bg-gray-50 p-5">
          <h3 class="font-bold text-sm text-gray-500 mb-3">사전 요구 사항</h3>
          <div class="flex flex-wrap gap-3">
            <span class="rounded bg-white border px-3 py-1.5 text-sm">Docker + Docker Compose</span>
            <span class="rounded bg-white border px-3 py-1.5 text-sm">서버 또는 PC (CPU 2코어, RAM 4GB 이상)</span>
          </div>
          <p class="mt-3 text-xs text-gray-500">Docker 설치: <a href="https://docs.docker.com/get-docker/" class="text-blue-600 hover:underline" target="_blank" rel="noopener">docs.docker.com/get-docker</a></p>
        </div>
        <div class="space-y-6">
          <div class="flex gap-4 items-start">
            <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">1</div>
            <div class="flex-1">
              <h3 class="font-bold">소스 받기</h3>
              <code class="mt-2 block rounded bg-gray-900 text-green-400 px-4 py-3 text-sm">git clone https://github.com/sapinfo/rigel.git && cd rigel</code>
            </div>
          </div>
          <div class="flex gap-4 items-start">
            <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">2</div>
            <div class="flex-1">
              <h3 class="font-bold">환경변수 설정</h3>
              <code class="mt-2 block rounded bg-gray-900 text-green-400 px-4 py-3 text-sm">cp .env.production.example .env</code>
              <p class="mt-2 text-xs text-gray-500"><code class="text-gray-400">.env</code> 파일을 열어서 비밀번호와 키를 설정합니다. 파일 안에 설명이 있습니다.</p>
            </div>
          </div>
          <div class="flex gap-4 items-start">
            <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">3</div>
            <div class="flex-1">
              <h3 class="font-bold">실행 (한 줄이면 끝)</h3>
              <code class="mt-2 block rounded bg-gray-900 text-green-400 px-4 py-3 text-sm">docker compose up -d</code>
              <p class="mt-2 text-xs text-gray-500">데이터베이스 + 인증 + 스토리지 + 앱 서버가 모두 자동으로 실행됩니다.</p>
            </div>
          </div>
          <div class="flex gap-4 items-start">
            <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">4</div>
            <div class="flex-1">
              <h3 class="font-bold">접속</h3>
              <p class="mt-2 text-sm text-gray-600">
                브라우저에서 <code class="rounded bg-gray-100 px-2 py-1">http://서버IP:3000</code> 접속 → 회원가입 → 조직 생성 → 사용 시작!
              </p>
            </div>
          </div>
        </div>
        <div class="mt-8 rounded-lg border bg-gray-50 p-5 text-sm">
          <h3 class="font-bold text-gray-700 mb-2">자주 쓰는 명령어</h3>
          <div class="space-y-1 text-xs font-mono text-gray-600">
            <p><span class="text-gray-400">중지:</span> docker compose down</p>
            <p><span class="text-gray-400">재시작:</span> docker compose restart</p>
            <p><span class="text-gray-400">업데이트:</span> git pull && docker compose up -d --build</p>
            <p><span class="text-gray-400">로그:</span> docker compose logs -f app</p>
          </div>
          <p class="mt-3 text-xs text-gray-500">데이터는 Docker volume에 영구 저장됩니다. 중지해도 데이터는 유지됩니다.</p>
        </div>

      {:else}
        <div class="mb-8 rounded-lg border bg-gray-50 p-5">
          <h3 class="font-bold text-sm text-gray-500 mb-3">사전 요구 사항</h3>
          <div class="flex flex-wrap gap-3">
            <span class="rounded bg-white border px-3 py-1.5 text-sm">Docker</span>
            <span class="rounded bg-white border px-3 py-1.5 text-sm">Node.js 22+</span>
            <span class="rounded bg-white border px-3 py-1.5 text-sm">Supabase CLI</span>
          </div>
        </div>
        <div class="space-y-6">
          <div class="flex gap-4 items-start">
            <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">1</div>
            <div class="flex-1">
              <h3 class="font-bold">소스 받기</h3>
              <code class="mt-2 block rounded bg-gray-900 text-green-400 px-4 py-3 text-sm">git clone https://github.com/sapinfo/rigel.git && cd rigel</code>
            </div>
          </div>
          <div class="flex gap-4 items-start">
            <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">2</div>
            <div class="flex-1">
              <h3 class="font-bold">Supabase 기동 + DB 초기화</h3>
              <div class="mt-2 rounded bg-gray-900 px-4 py-3 text-sm space-y-1">
                <div class="text-green-400">supabase start</div>
                <div class="text-green-400">supabase db reset</div>
              </div>
              <p class="mt-2 text-xs text-gray-500">71개 migration 적용 + 테스트 데이터 자동 생성</p>
            </div>
          </div>
          <div class="flex gap-4 items-start">
            <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">3</div>
            <div class="flex-1">
              <h3 class="font-bold">환경변수</h3>
              <code class="mt-2 block rounded bg-gray-900 text-green-400 px-4 py-3 text-sm">cp .env.example .env.local</code>
              <p class="mt-2 text-xs text-gray-500"><code class="text-gray-400">supabase status</code> 출력의 ANON_KEY, URL을 .env.local에 입력</p>
            </div>
          </div>
          <div class="flex gap-4 items-start">
            <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">4</div>
            <div class="flex-1">
              <h3 class="font-bold">실행</h3>
              <div class="mt-2 rounded bg-gray-900 px-4 py-3 text-sm space-y-1">
                <div class="text-green-400">npm install</div>
                <div class="text-green-400">npm run dev</div>
              </div>
            </div>
          </div>
          <div class="flex gap-4 items-start">
            <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">5</div>
            <div class="flex-1">
              <h3 class="font-bold">접속</h3>
              <p class="mt-2 text-sm text-gray-600">
                <code class="rounded bg-gray-100 px-2 py-1">http://localhost:5173</code> 접속
              </p>
              <div class="mt-3 rounded border bg-blue-50 p-3 text-xs text-gray-600">
                <p class="font-medium text-gray-700 mb-1">테스트 계정</p>
                <p>관리자: <code>m3test1@example.com</code> / <code>testpass1234</code></p>
                <p>결재자: <code>m5approver@example.com</code> / <code>testpass1234</code></p>
                <p>일반: <code>newuser@example.com</code> / <code>testpass1234</code></p>
              </div>
            </div>
          </div>
        </div>
      {/if}

      <div class="mt-10 text-center">
        <a href="https://github.com/sapinfo/rigel" class="inline-flex items-center gap-2 rounded-lg border-2 border-gray-900 px-5 py-2.5 text-sm font-medium hover:bg-gray-900 hover:text-white transition">
          GitHub에서 전체 소스 보기
        </a>
      </div>
    </div>
  </section>

  <!-- 기술지원 서비스 -->
  <section id="support" class="border-t bg-gray-50">
    <div class="mx-auto max-w-6xl px-6 py-20">
      <div class="text-center mb-12">
        <h2 class="text-3xl font-bold">직접 설치가 어려우신가요?</h2>
        <p class="mt-3 text-gray-600">전문가가 도와드립니다</p>
      </div>
      <div class="grid grid-cols-1 gap-6 md:grid-cols-3">
        <div class="rounded-xl border bg-white p-6 text-center">
          <div class="text-2xl mb-3">🔧</div>
          <h3 class="font-bold">설치 대행</h3>
          <p class="mt-2 text-sm text-gray-600">사내 서버에 Rigel을 설치하고<br/>초기 설정 + 사용자 교육까지</p>
          <p class="mt-4 text-lg font-bold text-blue-600">별도 문의</p>
        </div>
        <div class="rounded-xl border bg-white p-6 text-center">
          <div class="text-2xl mb-3">🛡️</div>
          <h3 class="font-bold">기술지원 계약</h3>
          <p class="mt-2 text-sm text-gray-600">월간 유지보수, 업데이트 적용<br/>장애 대응, 원격 지원</p>
          <p class="mt-4 text-lg font-bold text-blue-600">별도 문의</p>
        </div>
        <div class="rounded-xl border bg-white p-6 text-center">
          <div class="text-2xl mb-3">✨</div>
          <h3 class="font-bold">커스터마이징</h3>
          <p class="mt-2 text-sm text-gray-600">우리 회사 양식, 결재 규칙<br/>맞춤 개발 + 기존 시스템 연동</p>
          <p class="mt-4 text-lg font-bold text-blue-600">별도 문의</p>
        </div>
      </div>
    </div>
  </section>

  <!-- FAQ -->
  <section class="mx-auto max-w-3xl px-6 py-20">
    <h2 class="text-2xl font-bold text-center mb-10">자주 묻는 질문</h2>
    <div class="space-y-4">
      {#each [
        { q: '정말 무료인가요?', a: '네. 오픈소스 라이선스로 사용자 수, 기능 제한 없이 완전 무료입니다. 직접 서버에 설치해서 운영하시면 됩니다.' },
        { q: '서버 사양은 어느 정도 필요한가요?', a: 'CPU 2코어, RAM 4GB 이상이면 충분합니다. 50명 이하 조직 기준. 일반 사무용 워크스테이션도 가능합니다.' },
        { q: '한국 본사의 기존 그룹웨어와 연동 가능한가요?', a: '현재는 독립 운영 방식입니다. API 연동은 향후 업데이트 예정이며, 커스터마이징으로 대응 가능합니다.' },
        { q: '미국 현지 직원도 사용할 수 있나요?', a: '웹 브라우저만 있으면 어디서든 접속 가능합니다. 한국어 UI 기반이지만, 한국어를 사용하는 조직에 최적화되어 있습니다.' },
        { q: '데이터 보안은 어떻게 되나요?', a: '모든 데이터가 우리 서버에만 저장됩니다. 외부 클라우드로 데이터가 나가지 않으며, Row Level Security로 테넌트 간 데이터가 완전 격리됩니다.' },
        { q: '업데이트는 어떻게 하나요?', a: 'git pull 후 docker compose restart로 간단히 업데이트됩니다. 기술지원 계약 시 원격으로 대행해드립니다.' }
      ] as faq}
        <details class="group rounded-lg border bg-white">
          <summary class="flex cursor-pointer items-center justify-between px-5 py-4 text-sm font-medium">
            {faq.q}
            <span class="text-gray-400 group-open:rotate-180 transition-transform">▾</span>
          </summary>
          <p class="px-5 pb-4 text-sm text-gray-600">{faq.a}</p>
        </details>
      {/each}
    </div>
  </section>

  <!-- 최종 CTA -->
  <section class="bg-gradient-to-br from-blue-600 to-indigo-700 text-white">
    <div class="mx-auto max-w-6xl px-6 py-16 text-center">
      <h2 class="text-3xl font-bold">지금 바로 시작하세요</h2>
      <p class="mt-3 text-blue-200">서버 한 대면 우리 회사 전용 그룹웨어가 완성됩니다</p>
      <div class="mt-8 flex justify-center gap-4">
        <a href="https://github.com/sapinfo/rigel" class="rounded-lg bg-white px-6 py-3 text-sm font-medium text-gray-900 hover:bg-gray-100">
          GitHub에서 받기
        </a>
        <a href="/signup" class="rounded-lg border-2 border-white px-6 py-3 text-sm font-medium text-white hover:bg-white/10">
          데모 체험
        </a>
      </div>
    </div>
  </section>

  <!-- Footer -->
  <footer class="border-t bg-gray-50">
    <div class="mx-auto max-w-6xl px-6 py-10">
      <div class="flex flex-col items-center gap-4 md:flex-row md:justify-between">
        <div>
          <span class="font-bold text-gray-900">Rigel</span>
          <span class="ml-2 text-sm text-gray-500">재미 한국기업을 위한 오픈소스 그룹웨어</span>
        </div>
        <div class="flex gap-6 text-sm text-gray-500">
          <a href="https://github.com/sapinfo/rigel" class="hover:text-gray-900">GitHub</a>
          <a href="/login" class="hover:text-gray-900">로그인</a>
          <a href="/signup" class="hover:text-gray-900">회원가입</a>
        </div>
      </div>
      <p class="mt-6 text-center text-xs text-gray-400">© 2026 Rigel. MIT License.</p>
    </div>
  </footer>
</div>
