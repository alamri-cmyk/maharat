/**
 * جلب الدورات الظاهرة للجمهور فقط (مفعّلة).
 * الدورات ذات is_active = false لا تُرجع — لا تظهر للمسجلين ولا لغير المسجلين.
 */
(function () {
    var SUPABASE_URL = 'https://jjsvdmetspjcwlojeoqr.supabase.co';
    var SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impqc3ZkbWV0c3BqY3dsb2plb3FyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwMzgzMzIsImV4cCI6MjA5MzYxNDMzMn0.mQVqL6W3OPc5y5E3aUkI-A9W1fiz7IiqEWxPTzTy0WU';

    function normalizeAxes(axes) {
        if (Array.isArray(axes)) return axes.map(String).filter(Boolean);
        if (axes == null || axes === '') return [];
        if (typeof axes === 'string') {
            try {
                var p = JSON.parse(axes);
                if (Array.isArray(p)) return p.map(String).filter(Boolean);
            } catch (e) { /* ignore */ }
            return axes.split(/\r?\n/).map(function (s) { return s.trim(); }).filter(Boolean);
        }
        return [];
    }

    function inferCategory(title) {
        var t = (title || '').trim();
        if (/تعليم|تدريس|التعليم|الصف|المحتوى|الكتاب|جوجل|الجوال|التقويم|الواقع المعزز|دمج التقنية/.test(t)) return 'تعليمية';
        if (/تقنية|ذكاء|اصطناعي|سيبراني|بيانات|أوفيس|إدخال|معزز/.test(t)) return 'تقنية';
        if (/إدارة|موارد|مخاطر|أزمات|مبيعات|مشتريات|جودة|فساد|KPIS|مطاعم|فنادق|مكاتب|مشاريع|تفتيش|احتيال|بيوت الثقافة/.test(t)) return 'إدارية';
        return 'عامة';
    }

    function mapRow(row) {
        var category = row.category || inferCategory(row.title);
        var img = (row.img && String(row.img).trim()) || 'logo_maher.png';
        return {
            id: row.id,
            title: row.title || '',
            category: category,
            img: img,
            terms: row.terms || '',
            objective: row.objective || '',
            axes: normalizeAxes(row.axes),
        };
    }

    function normalizeTitle(title) {
        return (title || '').trim().replace(/\s+/g, ' ');
    }

    window.mergeCatalogWithLocal = function (remote, local) {
        if (!Array.isArray(remote)) return [];
        if (!Array.isArray(local) || !local.length) return remote;
        var byTitle = {};
        local.forEach(function (c) {
            var key = normalizeTitle(c.title);
            if (key) byTitle[key] = c;
        });
        return remote.map(function (row) {
            var loc = byTitle[normalizeTitle(row.title)];
            if (!loc) return row;
            var objective = (row.objective && String(row.objective).trim())
                ? row.objective
                : (loc.objective || '');
            var axes = (row.axes && row.axes.length) ? row.axes : normalizeAxes(loc.axes);
            return Object.assign({}, row, { objective: objective, axes: axes });
        });
    };

    window.fetchActiveCoursesForCatalog = async function () {
        if (!window.supabase || typeof window.supabase.createClient !== 'function') {
            throw new Error('مكتبة Supabase غير محمّلة');
        }
        var client = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
        var res = await client
            .from('courses')
            .select('*')
            .eq('is_active', true)
            .order('created_at', { ascending: false });
        if (res.error) throw res.error;
        return (res.data || []).map(mapRow);
    };
})();
