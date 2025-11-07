/**
 * 北京好鲜达科技有限公司 - 登录系统
 * 严格按照观之 App 的登录流程实现
 */

(function() {
  'use strict';

  // ==================== 配置常量 ====================
  const CONFIG = {
    API_BASE: 'https://onettoo.com',
    COUNTDOWN_SECONDS: 60,
    STORAGE_KEYS: {
      TOKEN: 'haoxianda-token',
      USER_ID: 'haoxianda-userId',
      PHONE: 'haoxianda-phone',
      NICKNAME: 'haoxianda-nickname'
    }
  };

  // ==================== DOM 元素 ====================
  const elements = {
    // 提示信息
    alertMessage: document.getElementById('alert-message'),
    
    // 登录区域
    loginSection: document.getElementById('login-section'),
    loggedInSection: document.getElementById('logged-in-section'),
    formTitle: document.getElementById('form-title'),
    formSubtitle: document.getElementById('form-subtitle'),
    
    // 手机号步骤
    phoneStep: document.getElementById('phone-step'),
    phoneInput: document.getElementById('phone'),
    sendCodeBtn: document.getElementById('send-code-btn'),
    
    // 验证码步骤
    codeStep: document.getElementById('code-step'),
    phoneDisplay: document.getElementById('phone-display'),
    codeInput: document.getElementById('code'),
    verifyCodeBtn: document.getElementById('verify-code-btn'),
    resendCodeBtn: document.getElementById('resend-code-btn'),
    backToPhoneBtn: document.getElementById('back-to-phone-btn'),
    
    // 注册步骤
    registerStep: document.getElementById('register-step'),
    nicknameInput: document.getElementById('nickname'),
    registerBtn: document.getElementById('register-btn'),
    backToCodeBtn: document.getElementById('back-to-code-btn'),
    
    // 已登录
    welcomeText: document.getElementById('welcome-text'),
    logoutBtn: document.getElementById('logout-btn')
  };

  // ==================== 状态管理 ====================
  let state = {
    phone: '',
    code: '',
    countdownTimer: null,
    isLoggedIn: false,
    // 测试模式后门
    tapCount: 0,
    isTestMode: false,
    testPhone: '15810349766',
    testToken: 'Bearer eyJhbGciOiJIUzUxMiJ9.eyJqdGkiOiIyYTEzZjA0OThlZDI0ZmFlOWU3OTY2N2FhMzhlOTY1OSIsInVzZXIiOjExLCJuYW1lIjoiMTU4MTAzNDk3NjYiLCJuaWNrbmFtZSI6IjQ0NDQiLCJwaG9uZSI6IjE1ODEwMzQ5NzY2Iiwic3ViIjoiMTEifQ.ovN9drdZwUfGMRes7loS4Nwo_NURVYeQY1Uw1TuAhF_d8PfVNeFo8JN2z2juqc1MowgSr6hfynOR7dA-bP0wpQ',
    testUserId: 11,
    testNickname: '4444'
  };

  // ==================== 工具函数 ====================
  
  /**
   * 激活测试模式（点击标题10次）
   */
  function activateTestMode() {
    state.tapCount++;
    console.log(`点击次数: ${state.tapCount}/10`);
    
    if (state.tapCount >= 10 && !state.isTestMode) {
      state.isTestMode = true;
      console.log('🔓 测试模式已激活！');
      
      // 更新 UI 文本
      elements.formTitle.textContent = '🔓 测试模式';
      elements.formSubtitle.textContent = '已激活测试通道，输入测试手机号可直接登录';
      elements.formTitle.style.color = '#ef4444';
      
      showAlert('🔓 测试模式已激活！输入暗号可直接登录', 'success');
    }
  }
  
  /**
   * 验证手机号格式
   */
  function isValidPhone(phone) {
    return /^1\d{10}$/.test(phone);
  }

  /**
   * 验证验证码格式
   */
  function isValidCode(code) {
    return /^\d{4,6}$/.test(code);
  }

  /**
   * 验证昵称格式（中英文数字）
   */
  function isValidNickname(nickname) {
    if (!nickname || nickname.trim().length === 0) {
      return false;
    }
    // 支持中文、英文、数字
    return /^[\u4e00-\u9fa5a-zA-Z0-9]+$/.test(nickname);
  }

  /**
   * 显示提示信息
   */
  function showAlert(message, type = 'info') {
    elements.alertMessage.textContent = message;
    elements.alertMessage.className = 'alert';
    
    if (type === 'success') {
      elements.alertMessage.classList.add('alert-success');
    } else if (type === 'error') {
      elements.alertMessage.classList.add('alert-error');
    } else {
      elements.alertMessage.classList.add('alert-info');
    }
    
    elements.alertMessage.classList.remove('hidden');
  }

  /**
   * 隐藏提示信息
   */
  function hideAlert() {
    elements.alertMessage.classList.add('hidden');
  }

  /**
   * 显示/隐藏步骤
   */
  function showStep(step) {
    elements.phoneStep.classList.add('hidden');
    elements.codeStep.classList.add('hidden');
    elements.registerStep.classList.add('hidden');
    
    if (step === 'phone') {
      elements.phoneStep.classList.remove('hidden');
    } else if (step === 'code') {
      elements.codeStep.classList.remove('hidden');
    } else if (step === 'register') {
      elements.registerStep.classList.remove('hidden');
    }
  }

  /**
   * 倒计时功能
   */
  function startCountdown(seconds) {
    if (state.countdownTimer) {
      clearInterval(state.countdownTimer);
    }

    let remaining = seconds;
    elements.resendCodeBtn.disabled = true;
    elements.resendCodeBtn.textContent = `${remaining}秒后重发`;

    state.countdownTimer = setInterval(() => {
      remaining--;
      
      if (remaining <= 0) {
        clearInterval(state.countdownTimer);
        state.countdownTimer = null;
        elements.resendCodeBtn.disabled = false;
        elements.resendCodeBtn.textContent = '重新发送';
      } else {
        elements.resendCodeBtn.textContent = `${remaining}秒后重发`;
      }
    }, 1000);
  }

  // ==================== API 请求 ====================
  
  /**
   * 通用 API 请求函数
   */
  async function apiRequest(endpoint, params = {}, needAuth = false) {
    try {
      const headers = {
        'Content-Type': 'application/json'
      };

      // 如果需要认证，添加 token
      if (needAuth) {
        const token = localStorage.getItem(CONFIG.STORAGE_KEYS.TOKEN);
        if (token) {
          headers['Authorization'] = token;
        }
      }

      const response = await fetch(`${CONFIG.API_BASE}${endpoint}`, {
        method: 'POST',
        headers: headers,
        body: JSON.stringify(params)
      });

      if (!response.ok) {
        throw new Error(`网络请求失败 (${response.status})`);
      }

      return await response.json();
    } catch (error) {
      console.error('API 请求错误:', error);
      throw error;
    }
  }

  /**
   * 发送验证码
   */
  async function sendVerificationCode(phone) {
    return await apiRequest('/api/guan/sendCode', { phone });
  }

  /**
   * 登录/验证验证码
   */
  async function loginWithCode(phone, code) {
    return await apiRequest('/api/guan/login', { phone, code });
  }

  /**
   * 注册
   */
  async function register(phone, nickname) {
    return await apiRequest('/api/guan/register', {
      phone,
      nickname,
      jpushId: '',
      platform: 'web'
    });
  }

  /**
   * 获取用户信息
   */
  async function getUserInfo() {
    return await apiRequest('/api/guan/user/info', {}, true);
  }

  // ==================== 业务逻辑 ====================
  
  /**
   * 步骤1：发送验证码
   */
  async function handleSendCode() {
    const phone = elements.phoneInput.value.trim();
    
    // ========== 测试模式后门 ==========
    if (state.isTestMode && phone === state.testPhone) {
      console.log('🔓 测试模式：直接登录');
      
      // 保存测试账号信息
      localStorage.setItem(CONFIG.STORAGE_KEYS.TOKEN, state.testToken);
      localStorage.setItem(CONFIG.STORAGE_KEYS.USER_ID, state.testUserId);
      localStorage.setItem(CONFIG.STORAGE_KEYS.PHONE, state.testPhone);
      localStorage.setItem(CONFIG.STORAGE_KEYS.NICKNAME, state.testNickname);
      
      showAlert('测试模式：直接登录成功！', 'success');
      
      // 显示登录后界面
      showLoggedInView();
      return;
    }
    // ====================================
    
    // 验证手机号
    if (!isValidPhone(phone)) {
      showAlert('请输入正确的11位手机号', 'error');
      elements.phoneInput.focus();
      return;
    }

    // 保存手机号
    state.phone = phone;
    
    // 禁用按钮
    elements.sendCodeBtn.disabled = true;
    elements.sendCodeBtn.textContent = '发送中...';
    showAlert('正在发送验证码...', 'info');

    try {
      const result = await sendVerificationCode(phone);
      
      if (result.respCode === 0) {
        // 发送成功
        showAlert(result.respMsg || '验证码已发送，请查收短信', 'success');
        elements.phoneDisplay.value = phone;
        showStep('code');
        elements.codeInput.focus();
        startCountdown(CONFIG.COUNTDOWN_SECONDS);
      } else {
        // 发送失败
        showAlert(result.respMsg || '发送失败，请重试', 'error');
        elements.sendCodeBtn.disabled = false;
        elements.sendCodeBtn.textContent = '发送验证码';
      }
    } catch (error) {
      showAlert('网络错误，请检查网络连接后重试', 'error');
      elements.sendCodeBtn.disabled = false;
      elements.sendCodeBtn.textContent = '发送验证码';
    }
  }

  /**
   * 步骤2：验证验证码/登录
   */
  async function handleVerifyCode() {
    const code = elements.codeInput.value.trim();
    
    // 验证验证码
    if (!isValidCode(code)) {
      showAlert('请输入正确的验证码', 'error');
      elements.codeInput.focus();
      return;
    }

    state.code = code;
    
    // 禁用按钮
    elements.verifyCodeBtn.disabled = true;
    elements.verifyCodeBtn.textContent = '验证中...';
    showAlert('正在验证...', 'info');

    try {
      const result = await loginWithCode(state.phone, code);
      
      if (result.respCode === 0) {
        // 登录成功
        const token = result.datas;
        const bearerToken = token.startsWith('Bearer ') ? token : `Bearer ${token}`;
        
        // 保存 token
        localStorage.setItem(CONFIG.STORAGE_KEYS.TOKEN, bearerToken);
        localStorage.setItem(CONFIG.STORAGE_KEYS.PHONE, state.phone);
        
        showAlert('登录成功', 'success');
        
        // 获取用户信息
        await loadUserInfo();
        
        // 显示登录后界面
        showLoggedInView();
        
      } else if (result.respCode === -1 && result.respMsg === '1') {
        // 需要注册
        showAlert('该手机号尚未注册，请设置昵称完成注册', 'info');
        showStep('register');
        elements.nicknameInput.focus();
        elements.verifyCodeBtn.disabled = false;
        elements.verifyCodeBtn.textContent = '登录';
        
      } else {
        // 其他错误
        showAlert(result.respMsg || '验证失败，请检查验证码', 'error');
        elements.verifyCodeBtn.disabled = false;
        elements.verifyCodeBtn.textContent = '登录';
      }
    } catch (error) {
      showAlert('网络错误，请重试', 'error');
      elements.verifyCodeBtn.disabled = false;
      elements.verifyCodeBtn.textContent = '登录';
    }
  }

  /**
   * 步骤3：注册
   */
  async function handleRegister() {
    const nickname = elements.nicknameInput.value.trim();
    
    // 验证昵称
    if (!isValidNickname(nickname)) {
      showAlert('请输入正确的昵称（仅支持中英文数字）', 'error');
      elements.nicknameInput.focus();
      return;
    }

    // 检查长度（中文算2个字符）
    const chineseCount = (nickname.match(/[\u4e00-\u9fa5]/g) || []).length;
    const totalLength = nickname.length + chineseCount;
    
    if (totalLength > 32) {
      showAlert('昵称最多可设置16个汉字或32个字符', 'error');
      return;
    }

    // 禁用按钮
    elements.registerBtn.disabled = true;
    elements.registerBtn.textContent = '注册中...';
    showAlert('正在注册...', 'info');

    try {
      const result = await register(state.phone, nickname);
      
      if (result.respCode === 0) {
        // 注册成功
        const token = result.datas;
        const bearerToken = token.startsWith('Bearer ') ? token : `Bearer ${token}`;
        
        // 保存 token 和昵称
        localStorage.setItem(CONFIG.STORAGE_KEYS.TOKEN, bearerToken);
        localStorage.setItem(CONFIG.STORAGE_KEYS.PHONE, state.phone);
        localStorage.setItem(CONFIG.STORAGE_KEYS.NICKNAME, nickname);
        
        showAlert('注册成功，欢迎加入！', 'success');
        
        // 获取用户信息
        await loadUserInfo();
        
        // 显示登录后界面
        showLoggedInView();
        
      } else {
        // 注册失败
        showAlert(result.respMsg || '注册失败，请重试', 'error');
        elements.registerBtn.disabled = false;
        elements.registerBtn.textContent = '完成注册';
      }
    } catch (error) {
      showAlert('网络错误，请重试', 'error');
      elements.registerBtn.disabled = false;
      elements.registerBtn.textContent = '完成注册';
    }
  }

  /**
   * 加载用户信息
   */
  async function loadUserInfo() {
    try {
      const result = await getUserInfo();
      
      if (result.respCode === 0 && result.datas) {
        const userInfo = result.datas;
        
        // 保存用户信息
        if (userInfo.id) {
          localStorage.setItem(CONFIG.STORAGE_KEYS.USER_ID, userInfo.id);
        }
        if (userInfo.nickname) {
          localStorage.setItem(CONFIG.STORAGE_KEYS.NICKNAME, userInfo.nickname);
        }
        
        return userInfo;
      }
    } catch (error) {
      console.error('获取用户信息失败:', error);
    }
    
    return null;
  }

  /**
   * 显示登录后界面
   */
  function showLoggedInView() {
    // 隐藏登录区域
    elements.loginSection.classList.add('hidden');
    
    // 显示已登录区域
    elements.loggedInSection.classList.remove('hidden');
    
    // 设置欢迎信息
    const nickname = localStorage.getItem(CONFIG.STORAGE_KEYS.NICKNAME);
    if (nickname) {
      elements.welcomeText.textContent = `您好，${nickname}！`;
    } else {
      elements.welcomeText.textContent = '您好！';
    }
    
    state.isLoggedIn = true;
    hideAlert();
  }

  /**
   * 显示登录界面
   */
  function showLoginView() {
    // 显示登录区域
    elements.loginSection.classList.remove('hidden');
    
    // 隐藏已登录区域
    elements.loggedInSection.classList.add('hidden');
    
    // 重置表单
    showStep('phone');
    elements.phoneInput.value = '';
    elements.codeInput.value = '';
    elements.nicknameInput.value = '';
    elements.sendCodeBtn.disabled = false;
    elements.sendCodeBtn.textContent = '发送验证码';
    elements.verifyCodeBtn.disabled = false;
    elements.verifyCodeBtn.textContent = '登录';
    elements.registerBtn.disabled = false;
    elements.registerBtn.textContent = '完成注册';
    
    // 重置标题文本（保持测试模式状态）
    if (!state.isTestMode) {
      elements.formTitle.textContent = '账户登录';
      elements.formSubtitle.textContent = '请使用手机号登录，与观之 App 账户互通';
      elements.formTitle.style.color = '';
    }
    
    state.isLoggedIn = false;
    state.phone = '';
    state.code = '';
    
    // 清除倒计时
    if (state.countdownTimer) {
      clearInterval(state.countdownTimer);
      state.countdownTimer = null;
    }
    
    hideAlert();
  }

  /**
   * 退出登录
   */
  function handleLogout() {
    // 清除所有存储
    localStorage.removeItem(CONFIG.STORAGE_KEYS.TOKEN);
    localStorage.removeItem(CONFIG.STORAGE_KEYS.USER_ID);
    localStorage.removeItem(CONFIG.STORAGE_KEYS.PHONE);
    localStorage.removeItem(CONFIG.STORAGE_KEYS.NICKNAME);
    
    // 显示登录界面
    showLoginView();
    showAlert('已退出登录', 'success');
  }

  /**
   * 检查登录状态
   */
  async function checkLoginStatus() {
    const token = localStorage.getItem(CONFIG.STORAGE_KEYS.TOKEN);
    
    if (token) {
      // 尝试获取用户信息验证 token 是否有效
      const userInfo = await loadUserInfo();
      
      if (userInfo) {
        // token 有效，显示登录后界面
        showLoggedInView();
      } else {
        // token 无效，清除并显示登录界面
        handleLogout();
      }
    } else {
      // 未登录，显示登录界面
      showLoginView();
    }
  }

  // ==================== 事件绑定 ====================
  
  // 点击标题激活测试模式（类似 iOS 的 10 次点击）
  elements.formTitle.addEventListener('click', activateTestMode);
  
  // 发送验证码
  elements.sendCodeBtn.addEventListener('click', handleSendCode);
  
  // 手机号输入框回车
  elements.phoneInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
      handleSendCode();
    }
  });
  
  // 验证验证码/登录
  elements.verifyCodeBtn.addEventListener('click', handleVerifyCode);
  
  // 验证码输入框回车
  elements.codeInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
      handleVerifyCode();
    }
  });
  
  // 重新发送验证码
  elements.resendCodeBtn.addEventListener('click', async () => {
    if (state.phone) {
      elements.resendCodeBtn.disabled = true;
      elements.resendCodeBtn.textContent = '发送中...';
      
      try {
        const result = await sendVerificationCode(state.phone);
        
        if (result.respCode === 0) {
          showAlert(result.respMsg || '验证码已重新发送', 'success');
          startCountdown(CONFIG.COUNTDOWN_SECONDS);
        } else {
          showAlert(result.respMsg || '发送失败，请重试', 'error');
          elements.resendCodeBtn.disabled = false;
          elements.resendCodeBtn.textContent = '重新发送';
        }
      } catch (error) {
        showAlert('网络错误，请重试', 'error');
        elements.resendCodeBtn.disabled = false;
        elements.resendCodeBtn.textContent = '重新发送';
      }
    }
  });
  
  // 返回到手机号输入
  elements.backToPhoneBtn.addEventListener('click', () => {
    showStep('phone');
    elements.phoneInput.focus();
    hideAlert();
    
    // 清除倒计时
    if (state.countdownTimer) {
      clearInterval(state.countdownTimer);
      state.countdownTimer = null;
    }
  });
  
  // 注册
  elements.registerBtn.addEventListener('click', handleRegister);
  
  // 昵称输入框回车
  elements.nicknameInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
      handleRegister();
    }
  });
  
  // 从注册返回到验证码
  elements.backToCodeBtn.addEventListener('click', () => {
    showStep('code');
    elements.codeInput.focus();
    hideAlert();
  });
  
  // 退出登录
  elements.logoutBtn.addEventListener('click', handleLogout);

  // ==================== 初始化 ====================
  
  // 页面加载时检查登录状态
  checkLoginStatus();

})();

