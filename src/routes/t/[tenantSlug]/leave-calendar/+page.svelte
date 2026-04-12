<script lang="ts">
  let { data } = $props();

  const slug = data.currentTenant.slug;
  const year = data.year ?? new Date().getFullYear();
  const month = data.month ?? (new Date().getMonth() + 1);
  const daysInMonth = data.daysInMonth ?? 31;
  const firstDayOfWeek = data.firstDayOfWeek ?? 0;
  const leaves = data.leaves ?? [];

  const monthNames = ['', '1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'];
  const dayNames = ['일', '월', '화', '수', '목', '금', '토'];

  const prevMonth = month === 1 ? `${year - 1}-12` : `${year}-${String(month - 1).padStart(2, '0')}`;
  const nextMonth = month === 12 ? `${year + 1}-01` : `${year}-${String(month + 1).padStart(2, '0')}`;

  // 날짜별 휴가 매핑
  type LeaveDay = { id: string; name: string; dept: string; type: string; color: string };

  const typeColors: Record<string, string> = {
    연차: 'bg-blue-100 text-blue-700',
    반차: 'bg-cyan-100 text-cyan-700',
    병가: 'bg-red-100 text-red-700',
    경조사: 'bg-purple-100 text-purple-700',
    무급: 'bg-gray-100 text-gray-700'
  };

  const calendarDays = $derived.by(() => {
    const days: { day: number; leaves: LeaveDay[] }[] = [];

    for (let d = 1; d <= daysInMonth; d++) {
      const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      const dayLeaves: LeaveDay[] = [];

      for (const leave of leaves) {
        if (dateStr >= leave.startDate && dateStr <= leave.endDate) {
          dayLeaves.push({
            id: leave.id,
            name: leave.drafterName,
            dept: leave.departmentName,
            type: leave.leaveType,
            color: typeColors[leave.leaveType] ?? 'bg-gray-100 text-gray-700'
          });
        }
      }
      days.push({ day: d, leaves: dayLeaves });
    }
    return days;
  });

  // 빈 셀 (월 시작 요일 맞춤)
  const emptyBefore = firstDayOfWeek;
</script>

<div class="space-y-4">
  <!-- 헤더 -->
  <div class="flex items-center justify-between">
    <h1 class="text-lg font-bold">휴가 캘린더</h1>
    <div class="flex items-center gap-2">
      <!-- 부서 필터 -->
      <select
        value={data.deptFilter}
        onchange={(e) => {
          const u = new URL(window.location.href);
          if (e.currentTarget.value) u.searchParams.set('dept', e.currentTarget.value);
          else u.searchParams.delete('dept');
          window.location.href = u.toString();
        }}
        class="rounded border px-2 py-1 text-sm"
      >
        <option value="">전체 부서</option>
        {#each data.departments as dept (dept.id)}
          <option value={dept.id}>{dept.name}</option>
        {/each}
      </select>
    </div>
  </div>

  <!-- 월 네비게이션 -->
  <div class="flex items-center justify-center gap-4">
    <a href="?month={prevMonth}&dept={data.deptFilter}" class="rounded border px-3 py-1 text-sm hover:bg-gray-50">◀</a>
    <span class="text-lg font-semibold">{year}년 {monthNames[month]}</span>
    <a href="?month={nextMonth}&dept={data.deptFilter}" class="rounded border px-3 py-1 text-sm hover:bg-gray-50">▶</a>
  </div>

  <!-- 범례 -->
  <div class="flex flex-wrap gap-2 text-xs">
    {#each Object.entries(typeColors) as [type, color] (type)}
      <span class="rounded px-2 py-0.5 {color}">{type}</span>
    {/each}
    <span class="text-gray-400">({leaves.length}건)</span>
  </div>

  <!-- 캘린더 그리드 -->
  <div class="rounded-lg border bg-white">
    <!-- 요일 헤더 -->
    <div class="grid grid-cols-7 border-b bg-gray-50">
      {#each dayNames as name, i (i)}
        <div class="px-1 py-2 text-center text-xs font-medium" class:text-red-500={i === 0} class:text-blue-500={i === 6} class:text-gray-500={i > 0 && i < 6}>
          {name}
        </div>
      {/each}
    </div>

    <!-- 날짜 셀 -->
    <div class="grid grid-cols-7">
      <!-- 빈 셀 -->
      {#each Array(emptyBefore) as _, i (i)}
        <div class="min-h-20 border-b border-r p-1"></div>
      {/each}

      <!-- 실제 날짜 -->
      {#each calendarDays as { day, leaves: dayLeaves } (day)}
        {@const dayOfWeek = (firstDayOfWeek + day - 1) % 7}
        <div class="min-h-20 border-b border-r p-1 {dayOfWeek === 0 ? 'bg-red-50' : dayOfWeek === 6 ? 'bg-blue-50' : ''}">
          <span class="text-xs font-medium" class:text-red-500={dayOfWeek === 0} class:text-blue-500={dayOfWeek === 6} class:text-gray-700={dayOfWeek > 0 && dayOfWeek < 6}>
            {day}
          </span>
          <div class="mt-0.5 space-y-0.5">
            {#each dayLeaves.slice(0, 3) as leave (leave.id + day)}
              <a href="/t/{slug}/approval/documents/{leave.id}" class="block truncate rounded px-1 py-0.5 text-[10px] {leave.color}" title="{leave.name} ({leave.dept}) - {leave.type}">
                {leave.name} {leave.type}
              </a>
            {/each}
            {#if dayLeaves.length > 3}
              <span class="text-[10px] text-gray-400">+{dayLeaves.length - 3}건</span>
            {/if}
          </div>
        </div>
      {/each}

      <!-- 나머지 빈 셀 -->
      {#each Array((7 - (emptyBefore + daysInMonth) % 7) % 7) as _, i (i)}
        <div class="min-h-20 border-b border-r p-1"></div>
      {/each}
    </div>
  </div>

  <!-- 이번 달 휴가 목록 -->
  {#if leaves.length > 0}
    <section class="rounded-lg border bg-white p-4">
      <h2 class="mb-2 text-sm font-semibold">이번 달 휴가 ({leaves.length}건)</h2>
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b text-left text-xs text-gray-500">
            <th class="px-2 py-1">이름</th>
            <th class="px-2 py-1">부서</th>
            <th class="px-2 py-1">종류</th>
            <th class="px-2 py-1">기간</th>
          </tr>
        </thead>
        <tbody>
          {#each leaves as leave (leave.id)}
            <tr class="border-b last:border-b-0">
              <td class="px-2 py-1.5 font-medium">{leave.drafterName}</td>
              <td class="px-2 py-1.5 text-gray-500">{leave.departmentName}</td>
              <td class="px-2 py-1.5">
                <span class="rounded px-1.5 py-0.5 text-xs {typeColors[leave.leaveType] ?? 'bg-gray-100'}">{leave.leaveType}</span>
              </td>
              <td class="px-2 py-1.5 text-xs text-gray-500">{leave.startDate} ~ {leave.endDate}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </section>
  {/if}
</div>
