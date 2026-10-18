// Village chat for Chronicle Clash (web build only).
// Talk to a villager hands-free (mic) or by typing. Replies come from the
// Echo Vision brain: an OpenAI-style chat service behind a small server that
// keeps the model key (worker/brain-proxy.js in the myechovision repo). No key
// lives in the game. A different brain (address, model, optional own key) can
// be set with the gear button; that is saved only in this browser.
//
// The game (VillageChat.gd) calls ccChat.open(ctx) / ccChat.update(ctx) /
// ccChat.close() and reads ccChat.poll() every frame for events.
(function () {
  if (window.ccChat) return;
  const DEFAULT = { url: 'https://echo-brain.houawan-ych.workers.dev', model: 'openai/gpt-oss-120b', key: '' };
  const STORE = 'cc-village-brain';
  const HF = 'cc-village-handsfree';
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  const EMO = ['normal', 'happy', 'sad', 'surprised', 'scared', 'angry'];
  let ctx = null, log = [], events = [], busy = false, speaking = false, listening = false, rec = null;
  let handsfree = load(HF, true), cfg = Object.assign({}, DEFAULT, load(STORE, {}));
  let ui = null, abort = null;

  function load(k, d) { try { const v = localStorage.getItem(k); return v == null ? d : JSON.parse(v); } catch (e) { return d; } }
  function save(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }
  function emit(e) { events.push(e); }

  // ---------------------------------------------------------------- brain
  const thinker = id => /gpt-oss|qwen-?3|qwq|deepseek|r1|think|o[134]-|gpt-5|grok-3-mini/i.test(id) || (/reason|grok-4/i.test(id) && !/non-reasoning/i.test(id));
  function prompt() {
    const c = ctx;
    const sys = `You are ${c.name}, the ${c.job} of ${c.place}, a small village in the fantasy kingdom of Chronicle Clash (knights, a sky citadel, a dark forest). Stay in character at all times.
About you: ${c.persona}
Right now it is ${c.time} (${c.daypart}) and you were ${c.doing}.${c.carrying ? ' You are carrying a load from your work.' : ''}
Your neighbours here: ${c.neighbours}. The road east or west leads to the next part of the village.
You are talking with ${c.hero}, a young knight${c.sword ? ' with a sword drawn' : ' with a sword on his back'}.
Rules: Answer with spoken words only, 1 or 2 short sentences, plain everyday speech. No narration, no stage directions, no asterisks, no lists. Never say you are an AI or mention modern things. You only know village life, your work, your neighbours and local rumours.
Start every answer with one feeling tag from this list: [normal] [happy] [sad] [surprised] [scared] [angry]. Example: [happy] Good morning to you, sir knight.`;
    return [{ role: 'system', content: sys }].concat(log.slice(-12).map(m => ({ role: m.who === 'me' ? 'user' : 'assistant', content: m.who === 'me' ? m.text : `[${m.emotion || 'normal'}] ${m.text}` })));
  }
  function parse(raw) {
    let t = String(raw || '').replace(/<think>[\s\S]*?(<\/think>|$)/g, '').trim(), emotion = 'normal';
    const m = t.match(/^[\[(]\s*(normal|happy|sad|surprised|scared|angry)\s*[\])]?[:\s-]*/i);
    if (m) { emotion = m[1].toLowerCase(); t = t.slice(m[0].length); }
    t = t.replace(/\*[^*]*\*/g, ' ').replace(/\[(normal|happy|sad|surprised|scared|angry)\]/gi, ' ');
    const n = (ctx ? ctx.name : '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    if (n) t = t.replace(new RegExp('^\\s*' + n + '\\s*:\\s*', 'i'), '');
    t = t.replace(/\s+/g, ' ').trim().replace(/^["\u201c](.*)["\u201d]$/, '$1').trim();
    return { emotion: EMO.includes(emotion) ? emotion : 'normal', text: t };
  }
  async function ask(hint) {
    const base = String(cfg.url || '').trim().replace(/\/+$/, '');
    const body = { model: cfg.model, messages: prompt(), temperature: 0.8, max_tokens: thinker(cfg.model) ? 700 : 160 };
    if (hint && thinker(cfg.model)) body.reasoning_effort = /qwen/i.test(cfg.model) ? 'none' : 'low';
    const headers = { 'Content-Type': 'application/json' };
    if (cfg.key) headers.Authorization = 'Bearer ' + cfg.key;
    abort = new AbortController();
    let r;
    try { r = await fetch(base + '/chat/completions', { method: 'POST', headers, body: JSON.stringify(body), signal: abort.signal }); }
    catch (e) { if (e.name === 'AbortError') throw e; throw Error('Could not reach the brain.'); }
    if (!r.ok) {
      if (body.reasoning_effort && (r.status === 400 || r.status === 422)) return ask(false);
      throw Error(r.status === 403 ? 'The brain server does not allow this website yet.' : r.status === 401 ? 'The brain key was not accepted.' : r.status === 429 ? 'The brain is busy. Try again in a moment.' : 'The brain answered with error ' + r.status + '.');
    }
    const d = await r.json();
    return parse(d.choices && d.choices[0] && d.choices[0].message ? d.choices[0].message.content : '');
  }

  // ---------------------------------------------------------------- talk
  async function send(text) {
    text = String(text || '').trim();
    if (!text || !ctx || busy) return;
    stopListening();
    log.push({ who: 'me', text });
    emit({ t: 'said', text });
    draw();
    busy = true;
    status('Thinking\u2026');
    let rep;
    try {
      rep = await ask(true);
      if (!rep.text) rep = await ask(false);
    } catch (e) {
      busy = false;
      if (e.name === 'AbortError' || !ctx) return;
      // The villager still answers with one of their own lines; the reason shows under the chat.
      rep = { emotion: 'normal', text: ctx.fallback[Math.floor(Math.random() * ctx.fallback.length)], offline: e.message };
    }
    busy = false;
    if (!ctx) return;
    if (!rep.text) rep.text = '...';
    log.push({ who: 'them', text: rep.text, emotion: rep.emotion });
    emit({ t: 'reply', text: rep.text, emotion: rep.emotion });
    draw();
    status(rep.offline ? rep.offline + ' (' + ctx.name + ' answered with a stock line.)' : '');
    speak(rep.text);
  }

  function pickVoice() {
    const vs = (window.speechSynthesis && speechSynthesis.getVoices()) || [];
    const en = vs.filter(v => /^en/i.test(v.lang));
    const pool = en.length ? en : vs;
    if (!pool.length) return null;
    const fem = /female|samantha|victoria|karen|zira|susan|moira|tessa|fiona|serena|hazel|libby|sonia|aria|jenny/i;
    const mal = /\bmale|daniel|alex|fred|david|mark|rishi|arthur|george|guy|ryan|thomas|oliver/i;
    const want = pool.filter(v => (ctx.female ? fem : mal).test(v.name) && !(ctx.female ? /\bmale/i : fem).test(v.name));
    const list = want.length ? want : pool;
    return list[ctx.seed % list.length];
  }
  function speak(text) {
    if (!window.speechSynthesis || !text) { afterSpeech(); return; }
    try {
      speechSynthesis.cancel();
      const u = new SpeechSynthesisUtterance(text);
      const v = pickVoice();
      if (v) u.voice = v;
      u.pitch = ctx.pitch; u.rate = ctx.rate;
      speaking = true;
      let done = false;
      const end = () => { if (done) return; done = true; speaking = false; emit({ t: 'speaking', on: false }); afterSpeech(); };
      u.onend = end; u.onerror = end;
      setTimeout(end, 4000 + text.length * 110);
      emit({ t: 'speaking', on: true });
      speechSynthesis.speak(u);
    } catch (e) { speaking = false; afterSpeech(); }
  }
  function afterSpeech() { if (ctx && handsfree && !busy) setTimeout(() => { if (ctx && handsfree && !busy && !speaking) listen(); }, 350); }

  function listen() {
    if (!SR) { status('Voice is not available in this browser. Type instead.'); handsfree = false; draw(); return; }
    if (listening || busy || speaking || !ctx) return;
    try {
      rec = new SR();
      rec.lang = navigator.language || 'en-US';
      rec.interimResults = true;
      rec.continuous = false;
      let final = '';
      rec.onresult = e => {
        let interim = '';
        for (let i = e.resultIndex; i < e.results.length; i++) {
          if (e.results[i].isFinal) final += e.results[i][0].transcript; else interim += e.results[i][0].transcript;
        }
        if (ui) ui.input.placeholder = interim || 'Listening\u2026';
      };
      rec.onerror = e => {
        if (e.error === 'not-allowed' || e.error === 'service-not-allowed') {
          handsfree = false; save(HF, false); draw();
          status('The microphone is blocked. Allow it for this site, then tap the mic. You can also type.');
        }
      };
      rec.onend = () => {
        listening = false; rec = null; draw();
        if (final.trim()) send(final);
        else if (ctx && handsfree && !busy && !speaking) setTimeout(listen, 250);
      };
      rec.start();
      listening = true;
      status('');
      draw();
    } catch (e) {
      listening = false;
      status('Tap the mic to talk.');
      draw();
    }
  }
  function stopListening() { if (rec) { try { rec.abort(); } catch (e) {} } rec = null; listening = false; }

  // ---------------------------------------------------------------- panel
  function el(tag, css, text) { const e = document.createElement(tag); if (css) e.style.cssText = css; if (text != null) e.textContent = text; return e; }
  function build() {
    const root = el('div', 'position:fixed;left:50%;top:max(8px,env(safe-area-inset-top));transform:translateX(-50%);width:min(94vw,560px);z-index:20;font:15px/1.35 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;color:#eef7ff;background:rgba(6,18,34,.9);border:2px solid rgba(95,227,255,.75);border-radius:14px;box-shadow:0 6px 24px rgba(0,0,0,.45);padding:8px 10px 10px;user-select:none;-webkit-user-select:none;touch-action:manipulation');
    const head = el('div', 'display:flex;align-items:center;gap:8px;margin-bottom:6px');
    const title = el('div', 'flex:1;font-weight:700;color:#5fe3ff;letter-spacing:.3px');
    const gear = el('button', btnCss(34) + 'font-size:17px', '\u2699');
    const x = el('button', btnCss(34) + 'font-size:18px', '\u2715');
    head.append(title, gear, x);
    const logBox = el('div', 'max-height:24vh;overflow-y:auto;display:flex;flex-direction:column;gap:4px;padding:2px 0 6px');
    const row = el('div', 'display:flex;gap:8px;align-items:center');
    const mic = el('button', btnCss(48) + 'font-size:22px;border-radius:50%', '\ud83c\udfa4');
    const input = el('input', 'flex:1;min-width:0;height:42px;border-radius:10px;border:1px solid rgba(160,190,220,.5);background:rgba(255,255,255,.08);color:#fff;padding:0 10px;font-size:16px');
    input.placeholder = 'Say something\u2026';
    input.enterKeyHint = 'send';
    const go = el('button', btnCss(48) + 'width:auto;padding:0 14px;font-weight:700;color:#ffcf6a', 'SEND');
    row.append(mic, input, go);
    const st = el('div', 'min-height:0;font-size:13px;color:#ffcf6a;margin-top:5px');
    const settings = el('div', 'display:none;margin-top:8px;border-top:1px solid rgba(95,227,255,.3);padding-top:8px;font-size:13px');
    const f = (label, val, ph, type) => { const w = el('label', 'display:block;margin:4px 0'); w.append(el('span', 'display:block;opacity:.8', label)); const i = el('input', 'width:100%;box-sizing:border-box;height:34px;border-radius:8px;border:1px solid rgba(160,190,220,.5);background:rgba(255,255,255,.08);color:#fff;padding:0 8px;font-size:15px'); i.value = val; i.placeholder = ph; if (type) i.type = type; w.append(i); settings.append(w); return i; };
    const fu = f('Brain address', cfg.url, DEFAULT.url);
    const fm = f('Model', cfg.model, DEFAULT.model);
    const fk = f('Key (only for your own service; leave empty for the Echo Vision brain)', cfg.key, 'empty', 'password');
    const srow = el('div', 'display:flex;gap:8px;margin-top:6px');
    const sv = el('button', btnCss(36) + 'width:auto;padding:0 12px', 'Save');
    const rs = el('button', btnCss(36) + 'width:auto;padding:0 12px', 'Echo Vision brain');
    srow.append(sv, rs);
    settings.append(srow);
    root.append(head, logBox, row, st, settings);
    for (const ev of ['pointerdown', 'touchstart', 'mousedown', 'keydown', 'keyup', 'wheel']) root.addEventListener(ev, e => e.stopPropagation());
    x.onclick = () => { emit({ t: 'closed' }); close(); };
    mic.onclick = () => { handsfree = !(handsfree && listening) ; save(HF, handsfree); if (handsfree) { if (window.speechSynthesis) speechSynthesis.cancel(); speaking = false; listen(); } else { stopListening(); status(''); } draw(); };
    go.onclick = () => { const t = input.value; input.value = ''; send(t); };
    input.onkeydown = e => { if (e.key === 'Enter') { const t = input.value; input.value = ''; send(t); } };
    input.onfocus = () => { stopListening(); draw(); };
    gear.onclick = () => { settings.style.display = settings.style.display === 'none' ? 'block' : 'none'; };
    sv.onclick = () => { cfg = { url: fu.value.trim() || DEFAULT.url, model: fm.value.trim() || DEFAULT.model, key: fk.value.trim() }; save(STORE, cfg); settings.style.display = 'none'; status('Brain saved.'); };
    rs.onclick = () => { cfg = Object.assign({}, DEFAULT); fu.value = cfg.url; fm.value = cfg.model; fk.value = ''; save(STORE, cfg); status('Using the Echo Vision brain.'); };
    document.body.append(root);
    return { root, title, logBox, mic, input, st };
  }
  function btnCss(h) { return `height:${h}px;min-width:${h}px;width:${h}px;border-radius:10px;border:1px solid rgba(95,227,255,.6);background:rgba(10,40,64,.9);color:#eef7ff;cursor:pointer;display:flex;align-items:center;justify-content:center;`; }
  function status(t) { if (ui) { ui.st.textContent = t || ''; } }
  function draw() {
    if (!ui || !ctx) return;
    ui.title.textContent = `${ctx.name} \u00b7 ${ctx.job}`;
    ui.logBox.textContent = '';
    for (const m of log.slice(-8)) {
      const line = el('div', m.who === 'me' ? 'align-self:flex-end;background:rgba(95,227,255,.16);border-radius:10px;padding:4px 9px;max-width:85%' : 'align-self:flex-start;background:rgba(216,180,90,.16);border-radius:10px;padding:4px 9px;max-width:85%');
      if (m.who !== 'me') line.append(el('b', 'color:#ffcf6a', ctx.name + ': '));
      line.append(document.createTextNode(m.text));
      ui.logBox.append(line);
    }
    ui.logBox.scrollTop = ui.logBox.scrollHeight;
    const on = handsfree && listening;
    ui.mic.style.background = on ? '#c3263a' : 'rgba(10,40,64,.9)';
    ui.mic.style.borderColor = on ? '#ff8a96' : 'rgba(95,227,255,.6)';
    ui.input.placeholder = busy ? ctx.name + ' is thinking\u2026' : on ? 'Listening\u2026 just talk' : 'Type, or tap the mic to talk';
  }

  // ---------------------------------------------------------------- game API
  function open(json) {
    ctx = JSON.parse(json);
    log = [];
    busy = false;
    if (!ui) ui = build();
    ui.root.style.display = 'block';
    draw();
    status(handsfree && SR ? '' : 'Type, or tap the mic to talk.');
    if (handsfree) listen();
  }
  function update(json) { if (ctx) Object.assign(ctx, JSON.parse(json)); }
  function close() {
    stopListening();
    if (abort) { try { abort.abort(); } catch (e) {} }
    if (window.speechSynthesis) speechSynthesis.cancel();
    ctx = null; busy = false; speaking = false;
    if (ui) ui.root.style.display = 'none';
  }
  function poll() { if (!events.length) return ''; const s = JSON.stringify(events); events = []; return s; }
  if (window.speechSynthesis) { speechSynthesis.getVoices(); speechSynthesis.onvoiceschanged = () => {}; }
  window.ccChat = { open, update, close, poll, send };
})();
