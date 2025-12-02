const TOKEN_KEY = 'admin_token'

export function getToken(): string | null {
  const token = localStorage.getItem(TOKEN_KEY)
  console.log('[Auth] getToken:', token ? `${token.substring(0, 20)}...` : 'null')
  return token
}

export function setToken(token: string): void {
  console.log('[Auth] setToken:', token.substring(0, 20) + '...')
  localStorage.setItem(TOKEN_KEY, token)
  console.log('[Auth] Token saved to localStorage')
}

export function removeToken(): void {
  console.log('[Auth] removeToken')
  localStorage.removeItem(TOKEN_KEY)
}

export function isAuthenticated(): boolean {
  const authenticated = !!getToken()
  console.log('[Auth] isAuthenticated:', authenticated)
  return authenticated
}
