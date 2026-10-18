// Chronicle Clash homepage: beta dialog, floating play button, and
// scroll-linked reveals/parallax that play forwards and in reverse.
(function () {
  var doc = document.documentElement;
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)');
  doc.classList.add('js');

  // ---- test cards: one template feeds the Beta section and the dialog
  var tpl = document.getElementById('tests-tpl');
  document.querySelectorAll('[data-tests]').forEach(function (box) {
    box.appendChild(tpl.content.cloneNode(true));
    box.querySelectorAll('.test .btn').forEach(function (a) { a.setAttribute('aria-label', 'Enter ' + a.closest('.test').querySelector('h3').textContent.replace(/^\W+/, '').trim()); });
  });

  // ---- dialog
  var dialog = document.querySelector('[data-beta-dialog]');
  var opener = null;
  function openBeta(e) {
    opener = e && e.currentTarget;
    if (typeof dialog.showModal === 'function') dialog.showModal(); else dialog.setAttribute('open', '');
    document.body.classList.add('modal-open');
    var first = dialog.querySelector('.test .btn');
    if (first) first.focus();
  }
  function closeBeta() { if (dialog.open) dialog.close(); }
  dialog.addEventListener('close', function () {
    document.body.classList.remove('modal-open');
    if (opener && opener.focus) opener.focus();
  });
  dialog.addEventListener('click', function (e) { if (e.target === dialog) closeBeta(); }); // backdrop
  dialog.querySelector('[data-close]').addEventListener('click', closeBeta);
  document.querySelectorAll('[data-open-beta]').forEach(function (b) { b.addEventListener('click', openBeta); });

  // ---- scroll effects
  var reveals = [].slice.call(document.querySelectorAll('[data-reveal]'));
  var parallax = [].slice.call(document.querySelectorAll('[data-parallax]'));
  var topbar = document.querySelector('[data-topbar]');
  var fab = document.querySelector('[data-fab]');
  var hero = document.querySelector('.hero');
  var beta = document.getElementById('beta');
  var ticking = false;

  function frame() {
    ticking = false;
    var vh = window.innerHeight;
    var y = window.scrollY || window.pageYOffset;
    topbar.classList.toggle('solid', y > 40);
    // Floating button: after the hero, hidden while the Beta section is on screen.
    var heroEnd = hero.offsetHeight * 0.7;
    var b = beta.getBoundingClientRect();
    fab.classList.toggle('show', y > heroEnd && !(b.top < vh * 0.7 && b.bottom > vh * 0.3));
    if (reduce.matches) return;
    for (var i = 0; i < reveals.length; i++) {
      var r = reveals[i].getBoundingClientRect();
      // 0 when the top edge is at the bottom of the screen, 1 once it is a third of the way up.
      var p = (vh - r.top) / (vh * 0.36);
      p = p < 0 ? 0 : p > 1 ? 1 : p;
      reveals[i].style.setProperty('--p', p.toFixed(3));
    }
    for (var j = 0; j < parallax.length; j++) {
      var el = parallax[j];
      var box = (el.parentElement || el).getBoundingClientRect();
      if (box.bottom < -200 || box.top > vh + 200) continue;
      var k = parseFloat(el.getAttribute('data-parallax')) || 0;
      var off = (box.top + box.height / 2 - vh / 2) * -k;
      // Never slide further than the image's spare margin (no empty edges).
      var lim = el.offsetHeight * 0.075;
      off = off > lim ? lim : off < -lim ? -lim : off;
      el.style.transform = 'translate3d(0,' + off.toFixed(1) + 'px,0)';
    }
  }
  function onScroll() { if (!ticking) { ticking = true; requestAnimationFrame(frame); } }
  function onMotion() {
    if (reduce.matches) {
      reveals.forEach(function (el) { el.style.setProperty('--p', '1'); });
      parallax.forEach(function (el) { el.style.transform = ''; });
    }
    frame();
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll, { passive: true });
  if (reduce.addEventListener) reduce.addEventListener('change', onMotion);
  onMotion();
})();
