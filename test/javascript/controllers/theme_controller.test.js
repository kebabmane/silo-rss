import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import ThemeController from '../../../app/javascript/controllers/theme_controller'

describe('ThemeController', () => {
  let controller

  beforeEach(() => {
    // Setup DOM
    document.documentElement.className = ''

    // Create a plain instance and set up methods
    controller = new ThemeController()
  })

  afterEach(() => {
    document.documentElement.className = ''
  })

  it('manages dark class based on theme state', () => {
    // Test that setTheme correctly manages the dark class
    controller.setTheme('dark')
    expect(document.documentElement.classList.contains('dark')).toBe(true)

    controller.setTheme('light')
    expect(document.documentElement.classList.contains('dark')).toBe(false)
  })

  it('toggles dark class when toggle is called', () => {
    // Start with light theme
    document.documentElement.classList.remove('dark')
    expect(document.documentElement.classList.contains('dark')).toBe(false)

    // Toggle to dark
    controller.toggle()
    expect(document.documentElement.classList.contains('dark')).toBe(true)

    // Toggle back to light
    controller.toggle()
    expect(document.documentElement.classList.contains('dark')).toBe(false)
  })

  it('correctly detects current theme from DOM', () => {
    // When dark class is present, toggle should detect it
    document.documentElement.classList.add('dark')
    controller.toggle()
    expect(document.documentElement.classList.contains('dark')).toBe(false)

    // When dark class is absent, toggle should set it
    controller.toggle()
    expect(document.documentElement.classList.contains('dark')).toBe(true)
  })
})
