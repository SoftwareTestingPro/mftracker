document.addEventListener('DOMContentLoaded', () => {

  // --- Mobile Navigation ---
  const navToggle = document.getElementById('nav-toggle');
  const navMenu = document.getElementById('nav-menu');
  const navLinks = document.querySelectorAll('.nav-link');

  if (navToggle && navMenu) {
    navToggle.addEventListener('click', () => {
      navMenu.classList.toggle('active');
      const icon = navToggle.querySelector('i');
      if (navMenu.classList.contains('active')) {
        icon.className = 'fas fa-xmark';
      } else {
        icon.className = 'fas fa-bars';
      }
    });

    // Close menu when link is clicked
    navLinks.forEach(link => {
      link.addEventListener('click', () => {
        navMenu.classList.remove('active');
        navToggle.querySelector('i').className = 'fas fa-bars';
      });
    });
  }

  // Navbar scroll effect
  const navbar = document.getElementById('navbar');
  window.addEventListener('scroll', () => {
    if (window.scrollY > 50) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
  });


  // --- Screenshot Slider ---
  const slider = document.getElementById('screenshot-slider');
  const slides = document.querySelectorAll('.slide');
  const prevBtn = document.getElementById('slider-prev');
  const nextBtn = document.getElementById('slider-next');
  const dotsContainer = document.getElementById('slider-dots');
  
  let currentSlide = 0;
  let slideInterval;
  const slideDuration = 4000; // 4 seconds

  // Initialize dots
  if (dotsContainer && slides.length > 0) {
    slides.forEach((_, index) => {
      const dot = document.createElement('div');
      dot.classList.add('dot');
      if (index === 0) dot.classList.add('active');
      dot.addEventListener('click', () => goToSlide(index));
      dotsContainer.appendChild(dot);
    });
  }

  const dots = document.querySelectorAll('.dot');

  function updateSlides() {
    slides.forEach((slide, index) => {
      if (index === currentSlide) {
        slide.classList.add('active');
      } else {
        slide.classList.remove('active');
      }
    });

    dots.forEach((dot, index) => {
      if (index === currentSlide) {
        dot.classList.add('active');
      } else {
        dot.classList.remove('active');
      }
    });
  }

  function nextSlide() {
    currentSlide = (currentSlide + 1) % slides.length;
    updateSlides();
  }

  function prevSlide() {
    currentSlide = (currentSlide - 1 + slides.length) % slides.length;
    updateSlides();
  }

  function goToSlide(index) {
    currentSlide = index;
    updateSlides();
    resetInterval();
  }

  function startInterval() {
    slideInterval = setInterval(nextSlide, slideDuration);
  }

  function resetInterval() {
    clearInterval(slideInterval);
    startInterval();
  }

  if (nextBtn && prevBtn) {
    nextBtn.addEventListener('click', () => {
      nextSlide();
      resetInterval();
    });

    prevBtn.addEventListener('click', () => {
      prevSlide();
      resetInterval();
    });
  }

  // Hover over phone pauses slider autoplay
  const phoneMockup = document.querySelector('.hero-mockup');
  if (phoneMockup) {
    phoneMockup.addEventListener('mouseenter', () => clearInterval(slideInterval));
    phoneMockup.addEventListener('mouseleave', startInterval);
  }

  // Start autoplay
  if (slides.length > 0) {
    startInterval();
  }


  // --- Mutual Fund Calculator ---
  const btnSip = document.getElementById('btn-sip');
  const btnLump = document.getElementById('btn-lump');
  
  const amountInput = document.getElementById('amount-input');
  const rateInput = document.getElementById('rate-input');
  const yearsInput = document.getElementById('years-input');
  
  const lblAmount = document.getElementById('lbl-amount');
  
  const valAmount = document.getElementById('val-amount');
  const valRate = document.getElementById('val-rate');
  const valYears = document.getElementById('val-years');
  
  const resInvested = document.getElementById('res-invested');
  const resReturns = document.getElementById('res-returns');
  const resTotal = document.getElementById('res-total');
  
  const investedBar = document.getElementById('invested-bar');
  const returnsBar = document.getElementById('returns-bar');
  const visInvestedAmount = document.getElementById('vis-invested-amount');
  const visReturnsAmount = document.getElementById('vis-returns-amount');

  let calcMode = 'sip'; // 'sip' or 'lump'

  if (btnSip && btnLump) {
    btnSip.addEventListener('click', () => {
      calcMode = 'sip';
      btnSip.classList.add('active');
      btnLump.classList.remove('active');
      lblAmount.textContent = 'Monthly Investment';
      
      // Update ranges/defaults for SIP
      amountInput.min = 500;
      amountInput.max = 100000;
      amountInput.step = 500;
      if (parseInt(amountInput.value) > 100000) amountInput.value = 5000;
      
      calculate();
    });

    btnLump.addEventListener('click', () => {
      calcMode = 'lump';
      btnLump.classList.add('active');
      btnSip.classList.remove('active');
      lblAmount.textContent = 'Total Investment';
      
      // Update ranges/defaults for Lump Sum
      amountInput.min = 5000;
      amountInput.max = 10000000;
      amountInput.step = 5000;
      if (parseInt(amountInput.value) < 5000) amountInput.value = 50000;
      
      calculate();
    });
  }

  function formatCurrency(value) {
    return '₹' + Math.round(value).toLocaleString('en-IN');
  }

  function calculate() {
    const P = parseFloat(amountInput.value);
    const r = parseFloat(rateInput.value);
    const t = parseFloat(yearsInput.value);
    
    // Update displays
    valAmount.textContent = formatCurrency(P);
    valRate.textContent = r + '%';
    valYears.textContent = t + (t === 1 ? ' Year' : ' Years');

    let totalInvested = 0;
    let totalValue = 0;
    let estReturns = 0;

    if (calcMode === 'sip') {
      const monthlyRate = r / 12 / 100;
      const months = t * 12;
      totalInvested = P * months;
      // Formula for Future Value of an Ordinary Annuity (SIP):
      // FV = P * [((1 + i)^n - 1) / i] * (1 + i)
      totalValue = P * ((Math.pow(1 + monthlyRate, months) - 1) / monthlyRate) * (1 + monthlyRate);
    } else {
      totalInvested = P;
      // Compound interest formula: FV = P * (1 + r)^t
      totalValue = P * Math.pow(1 + (r / 100), t);
    }

    estReturns = totalValue - totalInvested;

    // Set results
    resInvested.textContent = formatCurrency(totalInvested);
    resReturns.textContent = formatCurrency(estReturns);
    resTotal.textContent = formatCurrency(totalValue);

    // Update visualizer bars
    visInvestedAmount.textContent = formatCurrency(totalInvested);
    visReturnsAmount.textContent = formatCurrency(estReturns);

    const totalRatio = totalInvested + estReturns;
    const investedPercent = (totalInvested / totalRatio) * 100;
    const returnsPercent = (estReturns / totalRatio) * 100;

    investedBar.style.width = `${investedPercent}%`;
    returnsBar.style.width = `${returnsPercent}%`;
  }

  if (amountInput && rateInput && yearsInput) {
    amountInput.addEventListener('input', calculate);
    rateInput.addEventListener('input', calculate);
    yearsInput.addEventListener('input', calculate);
    
    // Initial run
    calculate();
  }
});
