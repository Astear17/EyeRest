document.documentElement.classList.add('js');
const body = document.body;
const themeButton = document.querySelector('[data-theme-toggle]');
if (localStorage.getItem('eyerest-theme') === 'light') body.classList.add('light');
themeButton?.addEventListener('click', () => { const isLight = body.classList.toggle('light'); themeButton.setAttribute('aria-pressed', String(isLight)); localStorage.setItem('eyerest-theme', isLight ? 'light' : 'dark'); });
const header = document.querySelector('[data-header]');
const updateHeader = () => header?.classList.toggle('is-scrolled', window.scrollY > 20);
updateHeader(); window.addEventListener('scroll', updateHeader, { passive: true });
if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) { const observer = new IntersectionObserver((entries) => entries.forEach((entry) => { if (entry.isIntersecting) { entry.target.classList.add('is-visible'); observer.unobserve(entry.target); } }), { threshold: 0.12 }); document.querySelectorAll('.reveal').forEach((element) => observer.observe(element)); } else { document.querySelectorAll('.reveal').forEach((element) => element.classList.add('is-visible')); }
