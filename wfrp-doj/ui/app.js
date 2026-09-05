(function () {
    'use strict';

    const RESOURCE = 'wfrp-doj';

    const $        = (id) => document.getElementById(id);
    const book     = $('duty-book');

    const statusDot   = $('status-dot');
    const dutyStatus  = $('duty-status');
    const toggleBtn   = $('toggle-duty-btn');
    const rosterList  = $('roster-list');
    const wagesHeld   = $('wages-held');
    const lawyer       = $('lawyer-menu');
    const lawyerList   = $('lawyer-alert-list');
    const lawyerOnline = $('lawyer-online');

    const ledger         = $('lawyer-ledger');
    const billForm       = $('lawyer-bill-form');
    const billPrompt     = $('lawyer-bill-prompt');
    const ledgerBalance  = $('ledger-balance');
    const ledgerHistory  = $('ledger-history');
    const withdrawAmount = $('ledger-withdraw-amount');
    const billTarget     = $('bill-target');
    const billAmount     = $('bill-amount');
    const billReason     = $('bill-reason');
    const bpFrom         = $('bill-prompt-from');
    const bpAmount       = $('bill-prompt-amount');
    const bpReason       = $('bill-prompt-reason');

    let canKick  = false;
    let menuOpen = null;
    let currentBillId = null;

    const GAVEL_URL = 'sounds/gavel.mp3';

    let _ctx = null;
    function audioCtx() {
        if (!_ctx) _ctx = new (window.AudioContext || window.webkitAudioContext)();
        if (_ctx.state === 'suspended') _ctx.resume();
        return _ctx;
    }

    let _gavelBuffer = null;
    (async function loadGavelFile() {
        try {
            const res = await fetch(GAVEL_URL);
            if (!res.ok) return;
            const bytes = await res.arrayBuffer();
            _gavelBuffer = await audioCtx().decodeAudioData(bytes);
        } catch (e) {
            _gavelBuffer = null;
        }
    })();

    function playGavel(volume = 0.75) {
        const ctx = audioCtx();

        if (_gavelBuffer) {
            const src  = ctx.createBufferSource();
            src.buffer = _gavelBuffer;
            const gain = ctx.createGain();
            gain.gain.value = volume;
            src.connect(gain).connect(ctx.destination);
            src.start();
            return;
        }

        playSynthGavel(ctx, volume);
    }

    function playSynthGavel(ctx, volume) {
        const now = ctx.currentTime;
        const master = ctx.createGain();
        master.gain.value = volume;
        master.connect(ctx.destination);

        const low = ctx.createOscillator();
        const lowGain = ctx.createGain();
        low.type = 'sine';
        low.frequency.setValueAtTime(220, now);
        low.frequency.exponentialRampToValueAtTime(70, now + 0.18);
        lowGain.gain.setValueAtTime(0.0001, now);
        lowGain.gain.exponentialRampToValueAtTime(0.85, now + 0.005);
        lowGain.gain.exponentialRampToValueAtTime(0.0001, now + 0.28);
        low.connect(lowGain).connect(master);
        low.start(now);
        low.stop(now + 0.3);

        const mid = ctx.createOscillator();
        const midGain = ctx.createGain();
        mid.type = 'triangle';
        mid.frequency.setValueAtTime(560, now);
        mid.frequency.exponentialRampToValueAtTime(210, now + 0.08);
        midGain.gain.setValueAtTime(0.0001, now);
        midGain.gain.exponentialRampToValueAtTime(0.35, now + 0.003);
        midGain.gain.exponentialRampToValueAtTime(0.0001, now + 0.11);
        mid.connect(midGain).connect(master);
        mid.start(now);
        mid.stop(now + 0.13);

        const bufLen = Math.floor(ctx.sampleRate * 0.03);
        const buf = ctx.createBuffer(1, bufLen, ctx.sampleRate);
        const data = buf.getChannelData(0);
        for (let i = 0; i < bufLen; i++) {
            const fade = Math.pow(1 - i / bufLen, 2);
            data[i] = (Math.random() * 2 - 1) * fade;
        }
        const noise = ctx.createBufferSource();
        noise.buffer = buf;
        const noiseFilter = ctx.createBiquadFilter();
        noiseFilter.type = 'bandpass';
        noiseFilter.frequency.value = 1800;
        noiseFilter.Q.value = 1.2;
        const noiseGain = ctx.createGain();
        noiseGain.gain.value = 0.55;
        noise.connect(noiseFilter).connect(noiseGain).connect(master);
        noise.start(now);
    }

    function show(el) { if (el) el.classList.remove('hidden'); }
    function hide(el) { if (el) el.classList.add('hidden'); }

    function hideAllMenus() {
        hide(book);
        hide(lawyer);
        hide(ledger);
        hide(billForm);
        hide(billPrompt);
        menuOpen = null;
    }

    function post(endpoint, data) {
        return fetch(`https://${RESOURCE}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {})
        }).catch(() => {});
    }

    function closeMenu() {
        post('close');
        hideAllMenus();
    }

    function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, (c) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
        }[c]));
    }

    function setDutyState(onDuty, label) {
        if (onDuty) {
            dutyStatus.textContent = `Presently on duty as ${label || 'DOJ'}`;
            toggleBtn.textContent = 'Sign Out';
            toggleBtn.classList.add('on-duty');
            statusDot.classList.add('on');
        } else {
            dutyStatus.textContent = 'Presently off duty';
            toggleBtn.textContent = 'Sign In';
            toggleBtn.classList.remove('on-duty');
            statusDot.classList.remove('on');
        }
    }

    function formatMoney(n) {
        n = Number(n) || 0;
        return Number.isInteger(n) ? String(n) : n.toFixed(2);
    }

    function setWages(amount) {
        if (!wagesHeld) return;
        const n = Number(amount) || 0;
        wagesHeld.textContent = `Wages held in book: $${formatMoney(n)}`;
        wagesHeld.classList.toggle('has-wages', n > 0);
    }

    function buildRoster(roster) {
        rosterList.innerHTML = '';
        if (!roster || roster.length === 0) {
            const li = document.createElement('li');
            li.className = 'empty';
            li.textContent = '— No officers presently on duty —';
            rosterList.appendChild(li);
            return;
        }

        roster.forEach((p) => {
            const li = document.createElement('li');

            const name = document.createElement('div');
            name.className = 'roster-name';
            name.innerHTML =
                `<strong>${escapeHtml(p.name)}` +
                (p.self ? ` <span class="self-marker">(you)</span>` : '') +
                `</strong>` +
                `<span class="grade-badge">${escapeHtml(p.grade)}</span>`;
            li.appendChild(name);

            const actionCell = document.createElement('span');
            if (canKick && !p.self) {
                const btn = document.createElement('button');
                btn.className = 'kick-btn';
                btn.textContent = 'Kick';
                btn.dataset.id = p.id;
                btn.addEventListener('click', (e) => {
                    e.stopPropagation();
                    post('kick', { target: p.id });
                });
                actionCell.appendChild(btn);
            }
            li.appendChild(actionCell);

            rosterList.appendChild(li);
        });
    }

    function renderAlert(a) {
        const li = document.createElement('li');
        li.className = 'alert-item';

        const head = document.createElement('div');
        head.className = 'alert-head';
        head.innerHTML =
            `<strong>${escapeHtml(a.sender || 'Unknown')}</strong>` +
            `<span class="alert-time">${escapeHtml(a.when || '')}</span>`;
        li.appendChild(head);

        const msg = document.createElement('p');
        msg.className = 'alert-msg';
        msg.textContent = a.message || '';
        li.appendChild(msg);

        const hasLoc = typeof a.x === 'number' && (a.x !== 0 || a.y !== 0);
        if (hasLoc) {
            const btn = document.createElement('button');
            btn.className = 'locate-btn';
            btn.textContent = 'Locate';
            btn.dataset.action = 'lawyer_locate';
            btn.dataset.x = a.x;
            btn.dataset.y = a.y;
            btn.dataset.z = a.z;
            li.appendChild(btn);
        }
        return li;
    }

    function buildAlerts(alerts) {
        lawyerList.innerHTML = '';
        if (!alerts || alerts.length === 0) {
            const li = document.createElement('li');
            li.className = 'empty';
            li.textContent = '— No alerts on record —';
            lawyerList.appendChild(li);
            return;
        }
        alerts.forEach((a) => lawyerList.appendChild(renderAlert(a)));
    }

    function addAlert(a) {
        if (menuOpen !== 'lawyer' || !a) return;
        const empty = lawyerList.querySelector('.empty');
        if (empty) empty.remove();
        lawyerList.insertBefore(renderAlert(a), lawyerList.firstChild);
    }

    function renderLedger(balance, history) {
        if (ledgerBalance) ledgerBalance.textContent = `$${formatMoney(balance)}`;
        if (!ledgerHistory) return;
        ledgerHistory.innerHTML = '';
        if (!history || history.length === 0) {
            const li = document.createElement('li');
            li.className = 'empty';
            li.textContent = '— No transactions —';
            ledgerHistory.appendChild(li);
            return;
        }
        history.forEach((t) => {
            const li = document.createElement('li');
            const debit = t.type === 'withdraw';
            li.className = 'ledger-row ' + (debit ? 'debit' : 'credit');
            const sign = debit ? '−' : '+';
            const detail = debit
                ? 'Withdrawal'
                : (escapeHtml(t.party || 'Bill') + (t.reason ? ' — ' + escapeHtml(t.reason) : ''));
            li.innerHTML =
                `<span class="ledger-amt">${sign}$${formatMoney(t.amount)}</span>` +
                `<span class="ledger-detail">${detail}</span>` +
                `<span class="ledger-when">${escapeHtml(t.when || '')}</span>`;
            ledgerHistory.appendChild(li);
        });
    }

    document.addEventListener('click', (e) => {
        const target = e.target.closest('[data-action]');
        if (!target) return;
        const action = target.dataset.action;

        switch (action) {
            case 'close':       return closeMenu();
            case 'toggle_duty': return post('toggle_duty');
            case 'lawyer_locate':
                post('lawyer_locate', {
                    x: Number(target.dataset.x),
                    y: Number(target.dataset.y),
                    z: Number(target.dataset.z)
                });
                hideAllMenus();
                return;
            case 'lawyer_ledger_withdraw': {
                const amt = Number(withdrawAmount && withdrawAmount.value);
                if (!amt || amt <= 0) return;
                post('lawyer_ledger_withdraw', { amount: amt });
                if (withdrawAmount) withdrawAmount.value = '';
                return;
            }
            case 'lawyer_bill_send': {
                const tgt = parseInt(billTarget && billTarget.value, 10);
                const amt = Number(billAmount && billAmount.value);
                const rsn = ((billReason && billReason.value) || '').trim();
                if (!tgt || !amt || amt <= 0 || !rsn) return;
                post('lawyer_bill_send', { target: tgt, amount: amt, reason: rsn });
                if (billTarget) billTarget.value = '';
                if (billAmount) billAmount.value = '';
                if (billReason) billReason.value = '';
                return;
            }
            case 'lawyer_bill_accept':
                post('lawyer_bill_respond', { billId: currentBillId, accept: true });
                hideAllMenus();
                return;
            case 'lawyer_bill_deny':
                post('lawyer_bill_respond', { billId: currentBillId, accept: false });
                hideAllMenus();
                return;
        }
    });

    document.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape' || !menuOpen) return;
        if (menuOpen === 'billprompt') {
            post('lawyer_bill_respond', { billId: currentBillId, accept: false });
            hideAllMenus();
        } else {
            closeMenu();
        }
    });

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d || !d.type) return;

        switch (d.type) {
            case 'openDutyBook':
                canKick = !!d.canKick;
                setDutyState(d.onDuty, d.gradeLabel);
                setWages(d.pendingPay || 0);
                buildRoster(d.roster || []);
                hideAllMenus();
                show(book);
                menuOpen = 'book';
                break;

            case 'updateDutyBook':
                if (typeof d.canKick === 'boolean') canKick = d.canKick;
                if (typeof d.onDuty   === 'boolean') setDutyState(d.onDuty, d.gradeLabel);
                if (typeof d.pendingPay === 'number') setWages(d.pendingPay);
                if (d.roster) buildRoster(d.roster);
                break;

            case 'gavelStrike':
                playGavel(typeof d.volume === 'number' ? d.volume : 0.75);
                break;

            case 'openLawyer':
                buildAlerts(d.alerts || []);
                if (lawyerOnline) lawyerOnline.textContent = String(d.online || 0);
                hideAllMenus();
                show(lawyer);
                menuOpen = 'lawyer';
                break;

            case 'lawyerAlertAdd':
                addAlert(d.alert);
                break;

            case 'openLedger':
                renderLedger(d.balance || 0, d.history || []);
                if (withdrawAmount) withdrawAmount.value = (Number(d.balance) > 0) ? Number(d.balance) : '';
                hideAllMenus();
                show(ledger);
                menuOpen = 'ledger';
                break;

            case 'openBill':
                if (billTarget) billTarget.value = '';
                if (billAmount) billAmount.value = '';
                if (billReason) billReason.value = '';
                hideAllMenus();
                show(billForm);
                menuOpen = 'bill';
                break;

            case 'openBillPrompt':
                currentBillId = d.billId;
                if (bpFrom)   bpFrom.textContent = d.from || '—';
                if (bpAmount) bpAmount.textContent = `$${formatMoney(d.amount || 0)}`;
                if (bpReason) bpReason.textContent = d.reason || '';
                hideAllMenus();
                show(billPrompt);
                menuOpen = 'billprompt';
                break;

            case 'closeBillPrompt':
                if (menuOpen === 'billprompt') hideAllMenus();
                currentBillId = null;
                break;

            case 'closeAll':
                hideAllMenus();
                break;
        }
    });
})();
