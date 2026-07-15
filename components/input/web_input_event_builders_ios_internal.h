// Copyright 2026 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef COMPONENTS_INPUT_WEB_INPUT_EVENT_BUILDERS_IOS_INTERNAL_H_
#define COMPONENTS_INPUT_WEB_INPUT_EVENT_BUILDERS_IOS_INTERNAL_H_

#include <cstdint>
#include <string_view>

#include "base/component_export.h"
#include "third_party/blink/public/common/input/web_keyboard_event.h"

namespace input::internal {

// Scalar representation of the tvOS UIKey data used to build a web keyboard
// event. Keeping UIKit objects out of this seam makes the conversion logic
// directly testable.
struct TVOSKeyEventData {
  uint32_t hid_usage = 0;
  std::u16string_view characters;
  std::u16string_view characters_ignoring_modifiers;
  int modifiers = 0;
  bool is_key_up = false;
  double timestamp_seconds = 0;
};

COMPONENT_EXPORT(INPUT)
blink::WebKeyboardEvent BuildWebKeyboardEventForTVOS(
    const TVOSKeyEventData& data);

}  // namespace input::internal

#endif  // COMPONENTS_INPUT_WEB_INPUT_EVENT_BUILDERS_IOS_INTERNAL_H_
