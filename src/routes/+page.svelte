<script lang="ts">
  let installTab = $state<'prod' | 'dev'>('prod');
</script>

<svelte:head>
  <title>Rigel — 재미 한국기업을 위한 오픈소스 그룹웨어</title>
  <meta name="description" content="한국식 전자결재(전결/대결/후결/합의/병렬) + 게시판 + 일정 + 근태 + 인사. 서버 한 대면 완전 무료. 오픈소스 셀프호스팅." />
  <link rel="canonical" href="https://rigelworks.io" />

  <!-- Open Graph -->
  <meta property="og:type" content="website" />
  <meta property="og:url" content="https://rigelworks.io" />
  <meta property="og:title" content="Rigel — 재미 한국기업을 위한 오픈소스 그룹웨어" />
  <meta property="og:description" content="한국식 전자결재(전결/대결/후결/합의/병렬) + 게시판 + 일정 + 근태 + 인사. 서버 한 대면 완전 무료." />
  <meta property="og:image" content="https://rigelworks.io/hero.png" />
  <meta property="og:locale" content="ko_KR" />
  <meta property="og:site_name" content="Rigel" />

  <!-- Twitter -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="Rigel — 재미 한국기업을 위한 오픈소스 그룹웨어" />
  <meta name="twitter:description" content="한국식 전자결재 + 게시판 + 일정 + 근태 + 인사. 오픈소스 셀프호스팅, 완전 무료." />
  <meta name="twitter:image" content="https://rigelworks.io/hero.png" />

  <!-- JSON-LD 구조화 데이터 -->
  {@html `<script type="application/ld+json">${JSON.stringify({
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "Rigel",
    "description": "재미 한국기업을 위한 오픈소스 그룹웨어. 한국식 전자결재 + 게시판 + 일정 + 근태 + 인사.",
    "applicationCategory": "BusinessApplication",
    "operatingSystem": "Linux, Windows, macOS",
    "offers": {
      "@type": "Offer",
      "price": "0",
      "priceCurrency": "USD"
    },
    "author": {
      "@type": "Organization",
      "name": "SAP Info",
      "url": "https://github.com/sapinfo"
    },
    "url": "https://rigelworks.io",
    "sameAs": [
      "https://github.com/sapinfo/rigel"
    ],
    "downloadUrl": "https://github.com/sapinfo/rigel",
    "softwareVersion": "3.1",
    "inLanguage": "ko"
  })}</script>`}
</svelte:head>

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
  <section class="mx-auto max-w-6xl px-6 py-16 lg:py-24">
    <div class="flex flex-col lg:flex-row lg:items-center lg:gap-12">
      <!-- 좌: 텍스트 -->
      <div class="lg:w-1/2">
        <div class="inline-block rounded-full bg-blue-50 px-4 py-1.5 text-sm text-blue-700 mb-6">
          오픈소스 · 무료 · 셀프 호스팅
        </div>
        <h1 class="text-4xl font-bold tracking-tight lg:text-5xl leading-tight">
          한국식 전자결재,<br/>
          <span class="text-blue-600">미국에서도 그대로.</span>
        </h1>
        <p class="mt-6 text-lg text-gray-600 leading-relaxed">
          전결, 대결, 후결, 합의, 병렬결재 — 한국 본사와 동일한 결재 체계를
          우리 서버에 직접 설치해서 무료로 운영하세요.
        </p>
        <div class="mt-8 flex flex-wrap gap-3">
          <a href="https://github.com/sapinfo/rigel" class="rounded-lg bg-gray-900 px-6 py-3 text-sm font-medium text-white hover:bg-gray-800">
            GitHub에서 받기
          </a>
          <a href="/signup" class="rounded-lg border-2 border-blue-600 px-6 py-3 text-sm font-medium text-blue-600 hover:bg-blue-50">
            지금 바로 체험
          </a>
        </div>
        <p class="mt-4 text-xs text-gray-400">
          👉 <strong>이 사이트가 실사용 데모입니다.</strong> 회원가입 후 바로 결재 올려보세요. 서버 한 대 + Docker만 있으면 자체 설치도 가능합니다.
        </p>
      </div>
      <!-- 우: 스크린샷 -->
      <div class="mt-10 lg:mt-0 lg:w-1/2">
        <img src="/hero.png" alt="Rigel 대시보드" class="rounded-xl shadow-2xl border" />
      </div>
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
      <p class="mt-3 text-gray-600">Supabase 공식 셀프호스팅 + Rigel 앱, 2단계로 설치</p>
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
          <p class="font-medium text-blue-900">Supabase 셀프호스팅 + Rigel 앱 분리 구조</p>
          <p class="mt-1">Supabase는 <strong>공식 가이드대로 직접 설치</strong>, Rigel 앱은 해당 Supabase에 연결합니다. Docker만 있으면 됩니다.</p>
        </div>

        <!-- 사전 요구 -->
        <div class="mb-8 rounded-lg border bg-gray-50 p-5">
          <h3 class="font-bold text-sm text-gray-500 mb-3">사전 요구 사항</h3>
          <div class="flex flex-wrap gap-3">
            <span class="rounded bg-white border px-3 py-1.5 text-sm">Linux (Ubuntu 24.04+) 권장</span>
            <span class="rounded bg-white border px-3 py-1.5 text-sm">Docker + Docker Compose</span>
            <span class="rounded bg-white border px-3 py-1.5 text-sm">Git</span>
            <span class="rounded bg-white border px-3 py-1.5 text-sm">서버 (CPU 4코어, RAM 16GB, 디스크 40GB)</span>
          </div>
          <div class="mt-3 text-xs text-gray-500">
            <p>Docker 설치: <a href="https://docs.docker.com/get-docker/" class="text-blue-600 hover:underline" target="_blank" rel="noopener">docs.docker.com/get-docker</a></p>
            <p class="mt-1">Node.js, Supabase CLI는 <strong>불필요</strong>합니다 (컨테이너로 실행).</p>
          </div>

          <div class="mt-4 rounded-md border-l-4 border-amber-400 bg-amber-50 p-3 text-xs text-amber-900">
            <p class="font-semibold mb-1">⚠️ 설치 경로 주의</p>
            <p>반드시 <strong>일반 유저 홈 디렉토리</strong>(<code class="bg-white px-1 rounded">$HOME</code>)에 설치하세요.</p>
            <p class="mt-1"><code class="bg-white px-1 rounded">/opt</code>, <code class="bg-white px-1 rounded">/usr/local</code> 같은 시스템 경로는 <strong>권한 문제로 Supabase 초기화 실패</strong>합니다 (bind mount된 init 스크립트 read 실패 → <code class="bg-white px-1 rounded">_supabase</code> DB 생성 안 됨).</p>
            <p class="mt-1">macOS Docker Desktop은 Settings → Resources → File Sharing에 설치 경로가 포함되어 있어야 합니다 (기본 <code class="bg-white px-1 rounded">/Users</code>는 포함됨).</p>
          </div>
        </div>

        <!-- Step 1: Supabase 공식 셀프호스팅 설치 -->
        <div class="mb-8">
          <div class="flex items-center gap-3 mb-4">
            <div class="flex h-9 w-9 items-center justify-center rounded-full bg-blue-600 text-white font-bold">1</div>
            <h3 class="font-bold text-lg">Supabase 공식 셀프호스팅 설치</h3>
          </div>

          <p class="text-sm text-gray-600 mb-3">
            Supabase 공식 가이드를 그대로 따릅니다:
            <a href="https://supabase.com/docs/guides/self-hosting/docker" class="text-blue-600 hover:underline" target="_blank" rel="noopener">supabase.com/docs/guides/self-hosting/docker</a>
          </p>

          <div class="rounded bg-gray-900 text-sm font-mono text-green-400 px-4 py-3 space-y-1 overflow-x-auto">
            <div><span class="text-gray-500"># 공식 저장소 클론 ($HOME 같은 일반 유저 경로에서)</span></div>
            <div>git clone --depth 1 https://github.com/supabase/supabase</div>
            <div>cd supabase/docker</div>
            <div>cp .env.example .env</div>
            <div class="mt-2"><span class="text-gray-500"># ⚡ 보안 키 자동 생성 (공식 유틸리티, 매우 편리)</span></div>
            <div><span class="text-yellow-300">sh ./utils/generate-keys.sh</span></div>
            <div class="mt-2"><span class="text-gray-500"># 기동</span></div>
            <div>docker compose pull</div>
            <div>docker compose up -d</div>
            <div class="mt-2"><span class="text-gray-500"># 검증: 모든 컨테이너 Healthy 인지 확인 (약 30~60초 소요)</span></div>
            <div>docker compose ps</div>
          </div>

          <div class="mt-4 rounded-md border-l-4 border-green-500 bg-green-50 p-3 text-xs text-green-900">
            <p class="font-semibold mb-1">💡 <code class="bg-white px-1 rounded">generate-keys.sh</code> 사용 권장</p>
            <p>Supabase 공식 유틸리티가 <code class="bg-white px-1 rounded">POSTGRES_PASSWORD</code>, <code class="bg-white px-1 rounded">JWT_SECRET</code>, <code class="bg-white px-1 rounded">ANON_KEY</code>, <code class="bg-white px-1 rounded">SERVICE_ROLE_KEY</code>, <code class="bg-white px-1 rounded">DASHBOARD_PASSWORD</code> 등 모든 시크릿을 자동 생성해 <code class="bg-white px-1 rounded">.env</code>에 주입합니다.</p>
            <p class="mt-1">실행 후 <code class="bg-white px-1 rounded">.env</code> 내용을 한 번 검토하세요.</p>
          </div>

          <div class="mt-3 rounded-md border-l-4 border-red-500 bg-red-50 p-3 text-xs text-red-900">
            <p class="font-semibold mb-1">❌ 기동 이후 비밀번호 변경 금지</p>
            <p>최초 <code class="bg-white px-1 rounded">docker compose up</code> 이후 <code class="bg-white px-1 rounded">POSTGRES_PASSWORD</code>를 바꾸면 <strong>supabase-analytics 컨테이너가 깨집니다</strong>. 키는 <em>기동 전에</em> 최종 확정하세요.</p>
          </div>
        </div>

        <!-- Step 2: Rigel 앱 설치 -->
        <div class="mb-8">
          <div class="flex items-center gap-3 mb-4">
            <div class="flex h-9 w-9 items-center justify-center rounded-full bg-blue-600 text-white font-bold">2</div>
            <h3 class="font-bold text-lg">Rigel 앱 설치</h3>
          </div>

          <p class="text-sm text-gray-600 mb-3">
            Supabase가 기동 중인 상태에서 Rigel 소스를 받고 <code class="bg-gray-100 px-1 rounded">install.sh</code>를 실행합니다.
            스크립트가 Supabase 기동 확인 → migration 71개 + seed 적용 → 앱 빌드/기동을 순차 수행합니다.
          </p>

          <div class="rounded bg-gray-900 text-sm font-mono text-green-400 px-4 py-3 space-y-1 overflow-x-auto">
            <div><span class="text-gray-500"># Rigel 소스 다운로드 (Supabase 디렉토리와 별도 위치)</span></div>
            <div>cd ~</div>
            <div>git clone https://github.com/sapinfo/rigel.git</div>
            <div>cd rigel</div>
            <div class="mt-2"><span class="text-gray-500"># .env 생성 + Supabase 연결 정보 입력</span></div>
            <div>cp .env.production.example .env</div>
            <div>nano .env <span class="text-gray-500"># PUBLIC_SUPABASE_ANON_KEY에 supabase/docker/.env의 ANON_KEY 값 붙여넣기</span></div>
            <div class="mt-2"><span class="text-gray-500"># 설치 실행</span></div>
            <div>./install.sh</div>
          </div>

          <div class="mt-4 rounded-md border-l-4 border-blue-500 bg-blue-50 p-3 text-xs text-blue-900">
            <p class="font-semibold mb-1">📋 .env에 입력할 값</p>
            <ul class="mt-1 space-y-0.5 list-disc list-inside">
              <li><code class="bg-white px-1 rounded">PUBLIC_SUPABASE_URL</code> = <code class="bg-white px-1 rounded">http://&lt;서버IP&gt;:8000</code> 또는 HTTPS 도메인 (예: <code class="bg-white px-1 rounded">https://api.your-domain.com</code>)</li>
              <li><code class="bg-white px-1 rounded">PUBLIC_SUPABASE_ANON_KEY</code> = <code class="bg-white px-1 rounded">supabase/docker/.env</code>의 <code class="bg-white px-1 rounded">ANON_KEY</code> 값 복사</li>
              <li><code class="bg-white px-1 rounded">SITE_URL</code> = 브라우저 접속 주소 (예: <code class="bg-white px-1 rounded">https://app.your-domain.com</code>)</li>
            </ul>
          </div>

          <div class="mt-3 rounded-md border-l-4 border-orange-500 bg-orange-50 p-3 text-xs text-orange-900">
            <p class="font-semibold mb-1">🌐 HTTPS · 도메인 붙이기</p>
            <p>공인 IP 없어도 가능합니다. <strong>Cloudflare Tunnel</strong>이 가장 쉽고 무료:</p>
            <ul class="mt-1 space-y-0.5 list-disc list-inside">
              <li>포트 개방 불필요 (아웃바운드만)</li>
              <li>SSL 인증서 자동 (Let's Encrypt 등 별도 관리 X)</li>
              <li>DDoS · WAF 기본 포함</li>
            </ul>
            <p class="mt-1">
              상세 절차:
              <a href="https://github.com/sapinfo/rigel/blob/main/docs/runbooks/cloudflare-tunnel-https.md" class="underline hover:text-orange-700">
                cloudflare-tunnel-https.md
              </a>
            </p>
          </div>
        </div>

        <!-- Step 3: 접속 -->
        <div class="mb-8">
          <div class="flex items-center gap-3 mb-4">
            <div class="flex h-9 w-9 items-center justify-center rounded-full bg-blue-600 text-white font-bold">3</div>
            <h3 class="font-bold text-lg">접속 및 초기 설정</h3>
          </div>

          <div class="rounded border bg-gray-50 p-4 text-sm space-y-2">
            <p><strong>Rigel:</strong> <code class="bg-white px-2 py-0.5 rounded">http://서버IP:3000</code> → 회원가입 → 조직 생성 → 양식 등록</p>
            <p><strong>Supabase Studio:</strong> <code class="bg-white px-2 py-0.5 rounded">http://서버IP:8000</code> → DB 관리 (아이디 <code>supabase</code>, 비번은 <code>supabase/docker/.env</code>의 <code>DASHBOARD_PASSWORD</code>)</p>
          </div>
        </div>

        <!-- 자주 쓰는 명령어 -->
        <div class="mt-8 rounded-lg border bg-gray-50 p-5 text-sm">
          <h3 class="font-bold text-gray-700 mb-2">자주 쓰는 명령어</h3>

          <div class="mb-3">
            <p class="text-xs font-semibold text-gray-500 uppercase mb-1">Rigel 앱 (<code>cd ~/rigel</code>)</p>
            <div class="space-y-1 text-xs font-mono text-gray-700">
              <p>docker compose down <span class="text-gray-400"># 중지</span></p>
              <p>docker compose restart <span class="text-gray-400"># 재시작</span></p>
              <p>docker compose logs -f app <span class="text-gray-400"># 로그</span></p>
              <p>git pull && docker compose up -d --build <span class="text-gray-400"># 업데이트</span></p>
            </div>
          </div>

          <div>
            <p class="text-xs font-semibold text-gray-500 uppercase mb-1">Supabase (<code>cd ~/supabase/docker</code>)</p>
            <div class="space-y-1 text-xs font-mono text-gray-700">
              <p>docker compose down <span class="text-gray-400"># 중지</span></p>
              <p>docker compose restart <span class="text-gray-400"># 재시작</span></p>
              <p>docker compose logs -f <span class="text-gray-400"># 로그</span></p>
            </div>
          </div>

          <p class="mt-3 text-xs text-red-600">⚠ <code class="bg-red-50 px-1 rounded">docker system prune</code> / <code class="bg-red-50 px-1 rounded">docker volume rm</code> 절대 금지 (데이터 손실)</p>
        </div>

        <!-- 트러블슈팅 -->
        <details class="mt-6 rounded-lg border bg-white p-5 text-sm">
          <summary class="cursor-pointer font-bold text-gray-700">🔧 문제 해결 (펼치기)</summary>

          <div class="mt-4 space-y-4">
            <div>
              <p class="font-semibold text-gray-900"><code>supabase-analytics</code> 컨테이너가 unhealthy / <code>_supabase</code> DB 없음 에러</p>
              <p class="mt-1 text-xs text-gray-600">대부분 <strong>설치 경로 권한 문제</strong>입니다. <code>/opt</code> 등에 sudo로 설치한 경우 bind mount된 <code>volumes/db/*.sql</code> init 스크립트를 postgres 컨테이너가 읽지 못해 <code>_supabase</code> DB가 생성되지 않습니다.</p>
              <p class="mt-1 text-xs text-gray-600"><strong>해결</strong>: 전체 디렉토리를 <code>$HOME</code> 하위로 이동 → <code>docker compose down && docker compose up -d</code> 재기동.</p>
            </div>

            <div>
              <p class="font-semibold text-gray-900"><code>POSTGRES_PASSWORD</code>를 변경했더니 analytics가 깨졌어요</p>
              <p class="mt-1 text-xs text-gray-600">최초 기동 이후 비밀번호 변경은 지원되지 않습니다. <strong>기동 전</strong>에 <code>generate-keys.sh</code> 또는 수동으로 값을 확정하세요.</p>
              <p class="mt-1 text-xs text-gray-600">복구: <code>supabase/docker</code>에서 <code>docker compose down</code> → <code>sudo rm -rf volumes/db/data</code> (데이터 손실!) → <code>docker compose up -d</code>.</p>
            </div>

            <div>
              <p class="font-semibold text-gray-900">macOS에서 bind mount 에러</p>
              <p class="mt-1 text-xs text-gray-600">Docker Desktop → Settings → Resources → File Sharing에 설치 경로가 포함되어 있어야 합니다. <code>/Users</code>는 기본 포함, <code>/opt</code>는 미포함입니다.</p>
            </div>

            <div>
              <p class="font-semibold text-gray-900">Rigel 앱에서 "Supabase not running" 에러</p>
              <p class="mt-1 text-xs text-gray-600"><code>install.sh</code>는 <code>supabase-db</code> 컨테이너와 <code>supabase_default</code> 네트워크가 있어야 동작합니다. Supabase 공식 스택이 기동 중인지 <code>docker compose ps</code>로 먼저 확인하세요.</p>
            </div>

            <div>
              <p class="font-semibold text-gray-900">회원가입 시 "Error sending confirmation email" 에러</p>
              <p class="mt-1 text-xs text-gray-600">SMTP가 구성되지 않은 상태에서 Supabase auth가 이메일 확인을 요구하기 때문입니다. 사내 그룹웨어라면 이메일 확인을 끄는 게 간단합니다.</p>
              <p class="mt-1 text-xs text-gray-600">해결: <code class="bg-gray-100 px-1 rounded">~/supabase/docker/.env</code>에 <code class="bg-gray-100 px-1 rounded">ENABLE_EMAIL_AUTOCONFIRM=true</code> (기본 <code>false</code>) 설정 후 auth 컨테이너 재기동:</p>
              <pre class="mt-1 text-xs bg-gray-900 text-green-400 rounded p-2 overflow-x-auto">cd ~/supabase/docker
docker compose up -d auth   # ⚠ restart 아님 — .env 재로드 필요</pre>
              <p class="mt-1 text-xs text-gray-600">실제 이메일 확인을 쓰려면 <code>.env</code>의 <code>SMTP_HOST/PORT/USER/PASS/ADMIN_EMAIL/SENDER_NAME</code>을 실제 SMTP 서버 값으로 구성.</p>
            </div>

            <div>
              <p class="font-semibold text-gray-900"><code>.env</code> 변경이 반영되지 않음</p>
              <p class="mt-1 text-xs text-gray-600"><code>docker compose restart</code>는 env를 재로드하지 않습니다. 반드시 <code>docker compose up -d &lt;service&gt;</code> (또는 전체 <code>up -d</code>)로 컨테이너를 재생성해야 새 env가 주입됩니다.</p>
            </div>
          </div>
        </details>

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
        { q: '서버 사양은 어느 정도 필요한가요?', a: 'CPU 4코어, RAM 16GB 이상을 권장합니다. DB + 인증 + API + 앱 서버 등 컨테이너 6개가 동시에 실행됩니다.' },
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
          <a href="https://rigelworks.io" class="ml-3 text-sm text-blue-600 hover:text-blue-700">rigelworks.io</a>
        </div>
        <div class="flex gap-6 text-sm text-gray-500">
          <a href="https://github.com/sapinfo/rigel" class="hover:text-gray-900">GitHub</a>
          <a href="https://github.com/sapinfo/rigel/issues" class="hover:text-gray-900">문의 · Issues</a>
          <a href="/login" class="hover:text-gray-900">로그인</a>
          <a href="/signup" class="hover:text-gray-900">회원가입</a>
        </div>
      </div>
      <p class="mt-6 text-center text-xs text-gray-400">
        © 2026 Rigel. MIT License. · 데모 사이트:
        <a href="https://app.rigelworks.io" class="hover:text-gray-600 underline">app.rigelworks.io</a>
      </p>
    </div>
  </footer>
</div>
