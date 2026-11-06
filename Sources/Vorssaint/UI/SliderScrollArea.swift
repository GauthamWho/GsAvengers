// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Enabled level controls receive the wheel before an enclosing horizontal strip.
protocol SliderScrollTarget: AnyObject {
    var acceptsSliderScroll: Bool { get }
}

