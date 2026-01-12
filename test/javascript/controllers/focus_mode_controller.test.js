import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import FocusModeController from '../../../app/javascript/controllers/focus_mode_controller'

describe('FocusModeController', () => {
  let controller, layoutElement, toggleElement, labelElement

  beforeEach(() => {
    // Setup DOM structure
    layoutElement = document.createElement('div')
    layoutElement.classList.add('dashboard-layout')

    toggleElement = document.createElement('button')
    labelElement = document.createElement('span')

    // Create controller instance
    controller = new FocusModeController()

    // Mock the target getters by directly setting properties
    controller.layoutTarget = layoutElement
    controller.toggleTarget = toggleElement
    controller.labelTarget = labelElement

    // Mock hasTargetProperty methods
    Object.defineProperty(controller, 'hasLayoutTarget', { value: true, configurable: true })
    Object.defineProperty(controller, 'hasToggleTarget', { value: true, configurable: true })
    Object.defineProperty(controller, 'hasLabelTarget', { value: true, configurable: true })
  })

  afterEach(() => {
    layoutElement = null
    toggleElement = null
    labelElement = null
  })

  it('initializes focused state', () => {
    controller.focused = false
    controller.updateToggleAppearance()

    expect(toggleElement.classList.contains('is-active')).toBe(false)
  })

  it('toggles focused state when toggle is called', () => {
    controller.focused = false
    const event = new MouseEvent('click', { bubbles: true })

    controller.toggle(event)

    expect(controller.focused).toBe(true)
  })

  it('updates toggle button with is-active class when focused', () => {
    controller.focused = true
    controller.updateToggleAppearance()

    expect(toggleElement.classList.contains('is-active')).toBe(true)
    expect(toggleElement.getAttribute('aria-pressed')).toBe('true')
  })

  it('removes is-active class from toggle button when not focused', () => {
    controller.focused = false
    controller.updateToggleAppearance()

    expect(toggleElement.classList.contains('is-active')).toBe(false)
    expect(toggleElement.getAttribute('aria-pressed')).toBe('false')
  })

  it('updates label text to Exit Focus when focused', () => {
    controller.focused = true
    controller.updateToggleAppearance()

    expect(labelElement.textContent).toBe('Exit Focus')
  })

  it('updates label text to Focus Mode when not focused', () => {
    controller.focused = false
    controller.updateToggleAppearance()

    expect(labelElement.textContent).toBe('Focus Mode')
  })

})
