// Mock localStorage for tests
const localStorageStore = {}

global.localStorage = {
  getItem: (key) => localStorageStore[key] || null,
  setItem: (key, value) => {
    localStorageStore[key] = String(value)
  },
  removeItem: (key) => {
    delete localStorageStore[key]
  },
  clear: () => {
    Object.keys(localStorageStore).forEach(key => {
      delete localStorageStore[key]
    })
  }
}
