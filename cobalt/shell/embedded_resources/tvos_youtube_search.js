// Copyright 2026 The Cobalt Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

(() => {
  'use strict';

  const ADAPTER_KEY = Symbol.for('cobalt.tvos.youtubeSearchAdapter');
  const installedAdapter = window[ADAPTER_KEY];
  if (installedAdapter) {
    installedAdapter.synchronizeRoute();
    return;
  }

  const INPUT_ID = 'cobalt-tvos-youtube-search-input';
  let input = null;
  let previousFocus = null;
  let active = false;
  let focusRetryTimers = [];
  let focusRecoveryTimer = null;

  function searchRoute() {
    const fragment = window.location.hash.replace(/^#/, '');
    const separator = fragment.indexOf('?');
    const path = separator === -1 ? fragment : fragment.slice(0, separator);
    if (path !== '/search') {
      return null;
    }

    const parameters = new URLSearchParams(
        separator === -1 ? '' : fragment.slice(separator + 1));
    return {
      isEntry: !parameters.has('q') && !parameters.has('vq') &&
          !parameters.has('query'),
    };
  }

  function restoreFocus() {
    const target = previousFocus;
    previousFocus = null;
    if (target && target.isConnected && typeof target.focus === 'function') {
      target.focus();
    } else if (document.body) {
      document.body.focus();
    }
  }

  function hideKeyboard() {
    if (navigator.virtualKeyboard &&
        typeof navigator.virtualKeyboard.hide === 'function') {
      navigator.virtualKeyboard.hide();
    }
  }

  function deactivate(shouldRestoreFocus) {
    if (!active) {
      return;
    }
    active = false;
    for (const timer of focusRetryTimers) {
      window.clearTimeout(timer);
    }
    focusRetryTimers = [];
    if (focusRecoveryTimer !== null) {
      window.clearTimeout(focusRecoveryTimer);
      focusRecoveryTimer = null;
    }
    hideKeyboard();
    input.blur();
    if (shouldRestoreFocus) {
      restoreFocus();
    } else {
      previousFocus = null;
    }
  }

  function navigateToSearch(query) {
    const url = new URL('/tv', window.location.origin);
    url.searchParams.set('launch', 'menu');

    const parameters = new URLSearchParams();
    parameters.set('inApp', 'true');
    parameters.set('q', query);
    url.hash = `/search?${parameters.toString()}`;
    window.location.assign(url.toString());
  }

  function focusInputAndShowKeyboard() {
    if (!active) {
      return;
    }
    input.focus({preventScroll: true});

    const hasUserActivation = !navigator.userActivation ||
        navigator.userActivation.hasBeenActive;
    if (hasUserActivation && navigator.virtualKeyboard &&
        typeof navigator.virtualKeyboard.show === 'function') {
      navigator.virtualKeyboard.show();
    }
  }

  function settleInputFocus() {
    // YouTube moves focus while it renders the search route. Retry for a short,
    // bounded period instead of fighting its focus manager every animation
    // frame, which repeatedly tears down the native tvOS keyboard session.
    for (const delay of [50, 150, 300]) {
      focusRetryTimers.push(window.setTimeout(() => {
        if (!active || document.activeElement === input) {
          return;
        }
        if (document.activeElement && document.activeElement !== document.body) {
          previousFocus = document.activeElement;
        }
        focusInputAndShowKeyboard();
      }, delay));
    }
  }

  function recoverInputFocus(event) {
    if (!active || event.target === input) {
      return;
    }
    if (event.target && event.target !== document.body) {
      previousFocus = event.target;
    }
    if (focusRecoveryTimer !== null) {
      window.clearTimeout(focusRecoveryTimer);
    }
    focusRecoveryTimer = window.setTimeout(() => {
      focusRecoveryTimer = null;
      if (active && document.activeElement !== input) {
        focusInputAndShowKeyboard();
      }
    }, 75);
  }

  function handleKeyDown(event) {
    if (!active || event.target !== input) {
      return;
    }

    if (event.key === 'Enter') {
      event.preventDefault();
      event.stopImmediatePropagation();
      const query = input.value.trim();
      input.value = '';
      deactivate(query.length === 0);
      if (query.length !== 0) {
        navigateToSearch(query);
      }
    } else if (event.key === 'Escape') {
      event.preventDefault();
      event.stopImmediatePropagation();
      input.value = '';
      deactivate(true);
    }
  }

  function ensureInput() {
    if (input && input.isConnected) {
      return input;
    }
    if (!document.body) {
      return null;
    }

    input = document.createElement('input');
    input.id = INPUT_ID;
    input.type = 'search';
    input.autocomplete = 'off';
    input.autocapitalize = 'none';
    input.spellcheck = false;
    input.tabIndex = -1;
    input.setAttribute('aria-label', 'Search YouTube');
    input.virtualKeyboardPolicy = 'manual';
    Object.assign(input.style, {
      position: 'fixed',
      left: '-10000px',
      top: '0',
      width: '1px',
      height: '1px',
      opacity: '0',
      pointerEvents: 'none',
    });
    input.addEventListener('keydown', handleKeyDown);
    document.body.appendChild(input);
    return input;
  }

  function activate() {
    if (active) {
      return;
    }
    if (!ensureInput()) {
      return;
    }

    previousFocus = document.activeElement === input ? null :
        document.activeElement;
    active = true;
    input.value = '';
    focusInputAndShowKeyboard();
    settleInputFocus();
  }

  function synchronizeRoute() {
    const route = searchRoute();
    if (!route || !route.isEntry) {
      deactivate(false);
      return;
    }
    activate();
  }

  Object.defineProperty(window, ADAPTER_KEY, {
    value: Object.freeze({synchronizeRoute}),
  });
  window.addEventListener('hashchange', synchronizeRoute);
  document.addEventListener('focusin', recoverInputFocus, true);
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', synchronizeRoute,
                              {once: true});
  } else {
    synchronizeRoute();
  }
})();
