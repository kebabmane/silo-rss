import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import InfiniteScrollController from '../../../app/javascript/controllers/infinite_scroll_controller'

describe('InfiniteScrollController', () => {
  let controller

  beforeEach(() => {
    // Mock IntersectionObserver
    global.IntersectionObserver = vi.fn(() => ({
      observe: vi.fn(),
      unobserve: vi.fn(),
      disconnect: vi.fn(),
    }))

    // Mock fetch
    global.fetch = vi.fn()

    // Create a plain instance
    controller = new InfiniteScrollController()

    // Create a mock element
    const mockElement = document.createElement('div')

    // Set up Stimulus value getters
    Object.defineProperty(controller, 'urlValue', {
      value: '/articles',
      writable: true,
      configurable: true
    })
    Object.defineProperty(controller, 'pageValue', {
      get: function() { return this._pageValue || 2 },
      set: function(v) { this._pageValue = v },
      configurable: true
    })
    Object.defineProperty(controller, 'filterValue', {
      value: 'unread',
      writable: true,
      configurable: true
    })
    Object.defineProperty(controller, 'element', {
      value: mockElement,
      writable: true,
      configurable: true
    })
  })

  afterEach(() => {
    vi.clearAllMocks()
  })

  it('initializes with default page value of 2', () => {
    expect(controller.pageValue).toBe(2)
  })

  it('resets page value when filter changes', () => {
    controller.pageValue = 5
    controller.filterValueChanged('all')
    expect(controller.pageValue).toBe(2)
  })

  it('prevents loading when already loading', () => {
    controller.isLoading = true
    controller.loadMore()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('debounces loadMore to prevent rapid requests', () => {
    controller.lastLoadTime = Date.now()

    // Try to load immediately
    controller.isLoading = false
    controller.loadMore()

    // Should not fetch because debounce threshold (300ms) hasn't passed
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('includes filter parameter in fetch URL', async () => {
    Object.defineProperty(controller, 'filterValue', {
      value: 'starred',
      writable: true,
      configurable: true
    })

    // Mock fetch to resolve
    global.fetch.mockResolvedValueOnce({
      text: async () => '<turbo-stream></turbo-stream>'
    })

    controller.lastLoadTime = 0
    controller.isLoading = false
    await controller.loadMore()

    const callUrl = global.fetch.mock.calls[0][0]
    expect(callUrl).toContain('filter=starred')
  })

  it('includes page parameter in fetch URL', async () => {
    controller.pageValue = 3

    // Mock fetch to resolve
    global.fetch.mockResolvedValueOnce({
      text: async () => '<turbo-stream></turbo-stream>'
    })

    controller.lastLoadTime = 0
    controller.isLoading = false
    await controller.loadMore()

    const callUrl = global.fetch.mock.calls[0][0]
    expect(callUrl).toContain('page=3')
  })

  it('increments page value after successful load', async () => {
    const initialPage = controller.pageValue

    // Mock fetch to resolve
    global.fetch.mockResolvedValueOnce({
      text: async () => '<turbo-stream></turbo-stream>'
    })

    controller.lastLoadTime = 0
    controller.isLoading = false
    await controller.loadMore()

    // Wait for promise to resolve
    await new Promise(resolve => setTimeout(resolve, 50))

    expect(controller.pageValue).toBe(initialPage + 1)
  })

  it('handles fetch errors gracefully', async () => {
    const consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})

    global.fetch.mockRejectedValueOnce(new Error('Network error'))

    controller.lastLoadTime = 0
    controller.isLoading = false
    await controller.loadMore()

    // Wait for promise to reject
    await new Promise(resolve => setTimeout(resolve, 50))

    expect(consoleErrorSpy).toHaveBeenCalled()
    expect(controller.isLoading).toBe(false)

    consoleErrorSpy.mockRestore()
  })

  it('sets up loading flag during request', async () => {
    global.fetch.mockResolvedValueOnce({
      text: async () => '<turbo-stream></turbo-stream>'
    })

    controller.lastLoadTime = 0
    controller.isLoading = false

    const loadMorePromise = controller.loadMore()
    expect(controller.isLoading).toBe(true)

    await loadMorePromise
    await new Promise(resolve => setTimeout(resolve, 50))

    expect(controller.isLoading).toBe(false)
  })

  it('makes request with Accept header', async () => {
    global.fetch.mockResolvedValueOnce({
      text: async () => '<turbo-stream></turbo-stream>'
    })

    controller.lastLoadTime = 0
    controller.isLoading = false
    await controller.loadMore()

    const options = global.fetch.mock.calls[0][1]
    expect(options.headers['Accept']).toBe('text/vnd.turbo-stream.html')
  })
})
