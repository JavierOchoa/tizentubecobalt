// Copyright 2026 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <UIKit/UIKit.h>

#include <string>

#include "components/input/web_input_event_builders_ios_internal.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "third_party/blink/public/common/input/web_input_event.h"
#include "ui/events/keycodes/dom/dom_code.h"
#include "ui/events/keycodes/dom/dom_key.h"
#include "ui/events/keycodes/keyboard_codes.h"

namespace input::internal {
namespace {

constexpr std::u16string_view kSymbolicA = u"UIKeyboardHIDUsageKeyboardA";

TVOSKeyEventData SymbolicKey(uint32_t hid_usage,
                             std::u16string_view characters,
                             int modifiers = 0) {
  return {.hid_usage = hid_usage,
          .characters = characters,
          .characters_ignoring_modifiers = characters,
          .modifiers = modifiers};
}

TEST(WebKeyboardEventBuilderTVOSTest, ConvertsLowercaseAndShiftedLetters) {
  blink::WebKeyboardEvent event = BuildWebKeyboardEventForTVOS(
      SymbolicKey(UIKeyboardHIDUsageKeyboardA, kSymbolicA));
  EXPECT_EQ(blink::WebInputEvent::Type::kKeyDown, event.GetType());
  EXPECT_EQ(UIKeyboardHIDUsageKeyboardA, event.native_key_code);
  EXPECT_EQ(ui::VKEY_A, event.windows_key_code);
  EXPECT_EQ(static_cast<int>(ui::DomCode::US_A), event.dom_code);
  EXPECT_EQ(ui::DomKey::FromCharacter('a'), event.dom_key);
  EXPECT_EQ(u'a', event.text[0]);
  EXPECT_EQ(u'a', event.unmodified_text[0]);

  event = BuildWebKeyboardEventForTVOS(
      SymbolicKey(UIKeyboardHIDUsageKeyboardA, kSymbolicA,
                  blink::WebInputEvent::kShiftKey));
  EXPECT_EQ(ui::DomKey::FromCharacter('A'), event.dom_key);
  EXPECT_EQ(u'A', event.text[0]);
  EXPECT_EQ(u'A', event.unmodified_text[0]);
  EXPECT_TRUE(event.GetModifiers() & blink::WebInputEvent::kShiftKey);
}

TEST(WebKeyboardEventBuilderTVOSTest, ConvertsDigitsAndShiftedPunctuation) {
  constexpr std::u16string_view kSymbolic1 = u"UIKeyboardHIDUsageKeyboard1";
  blink::WebKeyboardEvent event = BuildWebKeyboardEventForTVOS(
      SymbolicKey(UIKeyboardHIDUsageKeyboard1, kSymbolic1,
                  blink::WebInputEvent::kShiftKey));
  EXPECT_EQ(ui::VKEY_1, event.windows_key_code);
  EXPECT_EQ(ui::DomKey::FromCharacter('!'), event.dom_key);
  EXPECT_EQ(u'!', event.text[0]);
  EXPECT_EQ(u'!', event.unmodified_text[0]);

  constexpr std::u16string_view kSymbolicHyphen =
      u"UIKeyboardHIDUsageKeyboardHyphen";
  event = BuildWebKeyboardEventForTVOS(
      SymbolicKey(UIKeyboardHIDUsageKeyboardHyphen, kSymbolicHyphen,
                  blink::WebInputEvent::kShiftKey));
  EXPECT_EQ(ui::VKEY_OEM_MINUS, event.windows_key_code);
  EXPECT_EQ(ui::DomKey::FromCharacter('_'), event.dom_key);
  EXPECT_EQ(u'_', event.text[0]);
  EXPECT_EQ(u'_', event.unmodified_text[0]);
}

TEST(WebKeyboardEventBuilderTVOSTest, PreservesNumericKeypadWindowsCode) {
  const blink::WebKeyboardEvent event = BuildWebKeyboardEventForTVOS(
      SymbolicKey(UIKeyboardHIDUsageKeypad1, u"UIKeyboardHIDUsageKeypad1"));
  EXPECT_EQ(ui::DomCode::NUMPAD1, static_cast<ui::DomCode>(event.dom_code));
  EXPECT_EQ(ui::VKEY_NUMPAD1, event.windows_key_code);
  EXPECT_EQ(ui::DomKey::FromCharacter('1'), event.dom_key);
  EXPECT_EQ(u'1', event.text[0]);
  EXPECT_EQ(u'1', event.unmodified_text[0]);
  EXPECT_TRUE(event.GetModifiers() & blink::WebInputEvent::kIsKeyPad);
}

TEST(WebKeyboardEventBuilderTVOSTest, ConvertsSpaceBackspaceAndReturn) {
  blink::WebKeyboardEvent event = BuildWebKeyboardEventForTVOS(
      SymbolicKey(UIKeyboardHIDUsageKeyboardSpacebar,
                  u"UIKeyboardHIDUsageKeyboardSpacebar"));
  EXPECT_EQ(ui::VKEY_SPACE, event.windows_key_code);
  EXPECT_EQ(ui::DomKey::FromCharacter(' '), event.dom_key);
  EXPECT_EQ(u' ', event.text[0]);

  event = BuildWebKeyboardEventForTVOS(
      SymbolicKey(UIKeyboardHIDUsageKeyboardDeleteOrBackspace,
                  u"UIKeyboardHIDUsageKeyboardDeleteOrBackspace"));
  EXPECT_EQ(ui::VKEY_BACK, event.windows_key_code);
  EXPECT_EQ(ui::DomKey::BACKSPACE, event.dom_key);
  EXPECT_EQ(0, event.text[0]);
  EXPECT_EQ(0, event.unmodified_text[0]);

  event = BuildWebKeyboardEventForTVOS(
      SymbolicKey(UIKeyboardHIDUsageKeyboardReturnOrEnter,
                  u"UIKeyboardHIDUsageKeyboardReturnOrEnter"));
  EXPECT_EQ(ui::VKEY_RETURN, event.windows_key_code);
  EXPECT_EQ(ui::DomKey::ENTER, event.dom_key);
  EXPECT_EQ(u'\r', event.text[0]);
  EXPECT_EQ(u'\r', event.unmodified_text[0]);

  event = BuildWebKeyboardEventForTVOS(SymbolicKey(
      UIKeyboardHIDUsageKeyboardReturn, u"UIKeyboardHIDUsageKeyboardReturn"));
  EXPECT_EQ(ui::DomCode::ENTER, static_cast<ui::DomCode>(event.dom_code));
  EXPECT_EQ(ui::VKEY_RETURN, event.windows_key_code);
  EXPECT_EQ(ui::DomKey::ENTER, event.dom_key);
  EXPECT_EQ(u'\r', event.text[0]);
}

TEST(WebKeyboardEventBuilderTVOSTest, ConvertsArrowKeys) {
  struct TestCase {
    UIKeyboardHIDUsage hid_usage;
    ui::DomCode dom_code;
    ui::DomKey dom_key;
    ui::KeyboardCode key_code;
  } cases[] = {
      {UIKeyboardHIDUsageKeyboardLeftArrow, ui::DomCode::ARROW_LEFT,
       ui::DomKey::ARROW_LEFT, ui::VKEY_LEFT},
      {UIKeyboardHIDUsageKeyboardRightArrow, ui::DomCode::ARROW_RIGHT,
       ui::DomKey::ARROW_RIGHT, ui::VKEY_RIGHT},
      {UIKeyboardHIDUsageKeyboardUpArrow, ui::DomCode::ARROW_UP,
       ui::DomKey::ARROW_UP, ui::VKEY_UP},
      {UIKeyboardHIDUsageKeyboardDownArrow, ui::DomCode::ARROW_DOWN,
       ui::DomKey::ARROW_DOWN, ui::VKEY_DOWN},
  };
  for (const auto& test : cases) {
    const blink::WebKeyboardEvent event = BuildWebKeyboardEventForTVOS(
        SymbolicKey(test.hid_usage, u"UIKeyboardHIDUsageKeyboardArrow"));
    EXPECT_EQ(static_cast<int>(test.dom_code), event.dom_code);
    EXPECT_EQ(test.dom_key, event.dom_key);
    EXPECT_EQ(test.key_code, event.windows_key_code);
    EXPECT_EQ(0, event.text[0]);
  }
}

TEST(WebKeyboardEventBuilderTVOSTest, ConvertsModifiers) {
  struct TestCase {
    UIKeyboardHIDUsage hid_usage;
    ui::DomCode dom_code;
    ui::DomKey dom_key;
    ui::KeyboardCode key_code;
  } cases[] = {
      {UIKeyboardHIDUsageKeyboardLeftShift, ui::DomCode::SHIFT_LEFT,
       ui::DomKey::SHIFT, ui::VKEY_SHIFT},
      {UIKeyboardHIDUsageKeyboardRightShift, ui::DomCode::SHIFT_RIGHT,
       ui::DomKey::SHIFT, ui::VKEY_SHIFT},
      {UIKeyboardHIDUsageKeyboardLeftControl, ui::DomCode::CONTROL_LEFT,
       ui::DomKey::CONTROL, ui::VKEY_CONTROL},
      {UIKeyboardHIDUsageKeyboardRightAlt, ui::DomCode::ALT_RIGHT,
       ui::DomKey::ALT, ui::VKEY_MENU},
      {UIKeyboardHIDUsageKeyboardLeftGUI, ui::DomCode::META_LEFT,
       ui::DomKey::META, ui::VKEY_LWIN},
  };
  for (const auto& test : cases) {
    const blink::WebKeyboardEvent event = BuildWebKeyboardEventForTVOS(
        SymbolicKey(test.hid_usage, u"UIKeyboardHIDUsageKeyboardModifier"));
    EXPECT_EQ(static_cast<int>(test.dom_code), event.dom_code);
    EXPECT_EQ(test.dom_key, event.dom_key);
    EXPECT_EQ(test.key_code, event.windows_key_code);
    EXPECT_EQ(0, event.text[0]);
  }
}

TEST(WebKeyboardEventBuilderTVOSTest, FiltersControlModifiedText) {
  const blink::WebKeyboardEvent event = BuildWebKeyboardEventForTVOS(
      SymbolicKey(UIKeyboardHIDUsageKeyboardA, kSymbolicA,
                  blink::WebInputEvent::kControlKey));
  EXPECT_EQ(ui::DomKey::FromCharacter('a'), event.dom_key);
  EXPECT_EQ(0, event.text[0]);
  EXPECT_EQ(u'a', event.unmodified_text[0]);
}

TEST(WebKeyboardEventBuilderTVOSTest, ConvertsFunctionAndMediaKeys) {
  blink::WebKeyboardEvent event = BuildWebKeyboardEventForTVOS(SymbolicKey(
      UIKeyboardHIDUsageKeyboardF12, u"UIKeyboardHIDUsageKeyboardF12"));
  EXPECT_EQ(ui::DomCode::F12, static_cast<ui::DomCode>(event.dom_code));
  EXPECT_EQ(ui::DomKey::F12, event.dom_key);
  EXPECT_EQ(ui::VKEY_F12, event.windows_key_code);

  event = BuildWebKeyboardEventForTVOS(
      SymbolicKey(UIKeyboardHIDUsageKeyboardVolumeUp,
                  u"UIKeyboardHIDUsageKeyboardVolumeUp"));
  EXPECT_EQ(ui::DomCode::VOLUME_UP, static_cast<ui::DomCode>(event.dom_code));
  EXPECT_EQ(ui::DomKey::AUDIO_VOLUME_UP, event.dom_key);
  EXPECT_EQ(ui::VKEY_VOLUME_UP, event.windows_key_code);
  EXPECT_EQ(0, event.text[0]);
}

TEST(WebKeyboardEventBuilderTVOSTest, PreservesUnicodeCharacters) {
  blink::WebKeyboardEvent event = BuildWebKeyboardEventForTVOS(
      {.hid_usage = UIKeyboardHIDUsageKeyboardE,
       .characters = u"\u00e9",
       .characters_ignoring_modifiers = u"\u00e9"});
  EXPECT_EQ(ui::DomKey::FromCharacter(0x00e9), event.dom_key);
  EXPECT_EQ(u'\u00e9', event.text[0]);
  EXPECT_EQ(u'\u00e9', event.unmodified_text[0]);

  event = BuildWebKeyboardEventForTVOS(
      {.hid_usage = UIKeyboardHIDUsageKeyboardA,
       .characters = u"\U0001f600",
       .characters_ignoring_modifiers = u"\U0001f600"});
  EXPECT_EQ(ui::DomKey::FromCharacter(0x1f600), event.dom_key);
  EXPECT_EQ(0xd83d, event.text[0]);
  EXPECT_EQ(0xde00, event.text[1]);
  EXPECT_EQ(0, event.text[2]);
}

TEST(WebKeyboardEventBuilderTVOSTest, RejectsOversizedAndInvalidTextSafely) {
  blink::WebKeyboardEvent event =
      BuildWebKeyboardEventForTVOS({.hid_usage = UIKeyboardHIDUsageKeyboardA,
                                    .characters = u"abcd",
                                    .characters_ignoring_modifiers = u"abcd"});
  EXPECT_EQ(ui::DomKey::FromCharacter('a'), event.dom_key);
  EXPECT_EQ(0, event.text[0]);
  EXPECT_EQ(0, event.unmodified_text[0]);

  const std::u16string invalid(1, 0xd800);
  event =
      BuildWebKeyboardEventForTVOS({.hid_usage = UIKeyboardHIDUsageKeyboardA,
                                    .characters = invalid,
                                    .characters_ignoring_modifiers = invalid});
  EXPECT_EQ(ui::DomKey::FromCharacter('a'), event.dom_key);
  EXPECT_EQ(0, event.text[0]);
  EXPECT_EQ(0, event.unmodified_text[0]);
}

}  // namespace
}  // namespace input::internal
