import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import KeyboardController from '../../../app/javascript/controllers/keyboard_controller'

describe('KeyboardController', () => {
  let controller

  beforeEach(() => {
    // Create a plain instance
    controller = new KeyboardController()
    controller.currentArticleIndex = 0
  })

  afterEach(() => {
    // Cleanup
    const articles = document.querySelectorAll('[data-article-id]')
    articles.forEach(article => article.remove())
  })

  it('initializes with currentArticleIndex of 0', () => {
    expect(controller.currentArticleIndex).toBe(0)
  })

  it('ignores key presses when typing in input field', () => {
    const input = document.createElement('input')
    document.body.appendChild(input)

    const event = new KeyboardEvent('keydown', { key: 'j', bubbles: true })
    Object.defineProperty(event, 'target', { value: input, enumerable: true })

    const nextArticleSpy = vi.spyOn(controller, 'nextArticle')
    controller.handleKeyPress(event)

    expect(nextArticleSpy).not.toHaveBeenCalled()

    document.body.removeChild(input)
  })

  it('ignores key presses when typing in textarea', () => {
    const textarea = document.createElement('textarea')
    document.body.appendChild(textarea)

    const event = new KeyboardEvent('keydown', { key: 'j', bubbles: true })
    Object.defineProperty(event, 'target', { value: textarea, enumerable: true })

    const nextArticleSpy = vi.spyOn(controller, 'nextArticle')
    controller.handleKeyPress(event)

    expect(nextArticleSpy).not.toHaveBeenCalled()

    document.body.removeChild(textarea)
  })

  it('handles j key for next article', () => {
    const nextArticleSpy = vi.spyOn(controller, 'nextArticle')

    const event = new KeyboardEvent('keydown', { key: 'j', bubbles: true })
    event.preventDefault = vi.fn()
    Object.defineProperty(event, 'target', { value: document.body, enumerable: true })

    controller.handleKeyPress(event)

    expect(nextArticleSpy).toHaveBeenCalled()
    expect(event.preventDefault).toHaveBeenCalled()
  })

  it('handles k key for previous article', () => {
    const prevArticleSpy = vi.spyOn(controller, 'previousArticle')

    const event = new KeyboardEvent('keydown', { key: 'k', bubbles: true })
    event.preventDefault = vi.fn()
    Object.defineProperty(event, 'target', { value: document.body, enumerable: true })

    controller.handleKeyPress(event)

    expect(prevArticleSpy).toHaveBeenCalled()
    expect(event.preventDefault).toHaveBeenCalled()
  })

  it('handles m key for toggle read', () => {
    const toggleReadSpy = vi.spyOn(controller, 'toggleRead')

    const event = new KeyboardEvent('keydown', { key: 'm', bubbles: true })
    event.preventDefault = vi.fn()
    Object.defineProperty(event, 'target', { value: document.body, enumerable: true })

    controller.handleKeyPress(event)

    expect(toggleReadSpy).toHaveBeenCalled()
  })

  it('handles s key for toggle star', () => {
    const toggleStarSpy = vi.spyOn(controller, 'toggleStar')

    const event = new KeyboardEvent('keydown', { key: 's', bubbles: true })
    event.preventDefault = vi.fn()
    Object.defineProperty(event, 'target', { value: document.body, enumerable: true })

    controller.handleKeyPress(event)

    expect(toggleStarSpy).toHaveBeenCalled()
  })

  it('handles a key for archive', () => {
    const archiveSpy = vi.spyOn(controller, 'archive')

    const event = new KeyboardEvent('keydown', { key: 'a', bubbles: true })
    event.preventDefault = vi.fn()
    Object.defineProperty(event, 'target', { value: document.body, enumerable: true })

    controller.handleKeyPress(event)

    expect(archiveSpy).toHaveBeenCalled()
  })

  it('handles v key for open original', () => {
    const openOriginalSpy = vi.spyOn(controller, 'openOriginal')

    const event = new KeyboardEvent('keydown', { key: 'v', bubbles: true })
    event.preventDefault = vi.fn()
    Object.defineProperty(event, 'target', { value: document.body, enumerable: true })

    controller.handleKeyPress(event)

    expect(openOriginalSpy).toHaveBeenCalled()
  })

  it('navigates to next article', () => {
    const article1 = document.createElement('div')
    article1.setAttribute('data-article-id', '1')
    document.body.appendChild(article1)

    const article2 = document.createElement('div')
    article2.setAttribute('data-article-id', '2')
    document.body.appendChild(article2)

    const clickSpy = vi.spyOn(article2, 'click')

    controller.nextArticle()

    expect(clickSpy).toHaveBeenCalled()
    expect(controller.currentArticleIndex).toBe(1)
  })

  it('clamps nextArticle at end of articles', () => {
    const article1 = document.createElement('div')
    article1.setAttribute('data-article-id', '1')
    document.body.appendChild(article1)

    const article2 = document.createElement('div')
    article2.setAttribute('data-article-id', '2')
    document.body.appendChild(article2)

    controller.currentArticleIndex = 1 // Already at last article

    controller.nextArticle()

    expect(controller.currentArticleIndex).toBe(1)
  })

  it('navigates to previous article', () => {
    const article1 = document.createElement('div')
    article1.setAttribute('data-article-id', '1')
    document.body.appendChild(article1)

    const article2 = document.createElement('div')
    article2.setAttribute('data-article-id', '2')
    document.body.appendChild(article2)

    const clickSpy = vi.spyOn(article1, 'click')
    controller.currentArticleIndex = 1

    controller.previousArticle()

    expect(clickSpy).toHaveBeenCalled()
    expect(controller.currentArticleIndex).toBe(0)
  })

  it('clamps previousArticle at beginning', () => {
    const article1 = document.createElement('div')
    article1.setAttribute('data-article-id', '1')
    document.body.appendChild(article1)

    controller.currentArticleIndex = 0

    controller.previousArticle()

    expect(controller.currentArticleIndex).toBe(0)
  })

  it('clicks toggleRead button if exists', () => {
    const button = document.createElement('button')
    button.setAttribute('data-turbo-method', 'patch')
    button.setAttribute('formaction', '/articles/123/toggle_read')
    document.body.appendChild(button)

    const clickSpy = vi.spyOn(button, 'click')

    controller.toggleRead()

    expect(clickSpy).toHaveBeenCalled()

    document.body.removeChild(button)
  })
})
