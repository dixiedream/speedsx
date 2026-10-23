/// UI Module - Re-exports all UI components
/// This module provides backwards compatibility by re-exporting all public symbols

// Sub-modules
pub const types = @import("types.zig");
pub const renderer = @import("renderer.zig");
pub const state = @import("state.zig");
pub const widgets = @import("widgets.zig");
pub const drawing = @import("drawing.zig");

// Re-export types
pub const Layout = types.Layout;
pub const Colors = types.Colors;
pub const TextFieldId = types.TextFieldId;
pub const DragType = types.DragType;
pub const DropTarget = types.DropTarget;
pub const AppState = types.AppState;
pub const InputState = types.InputState;
pub const TextInputState = types.TextInputState;
pub const DragDropState = types.DragDropState;
pub const ScrollState = types.ScrollState;
pub const ScrollBounds = types.ScrollBounds;
pub const ContextMenuState = types.ContextMenuState;
pub const ClipboardState = types.ClipboardState;
pub const SampleFileEntry = types.SampleFileEntry;
pub const SampleBrowserState = types.SampleBrowserState;
pub const SampleBrowserAction = types.SampleBrowserAction;
pub const KitChainAction = types.KitChainAction;
pub const WaveEditorState = types.WaveEditorState;
pub const WaveEditorAction = types.WaveEditorAction;
pub const ActionButtonsResult = types.ActionButtonsResult;
pub const FileBarAction = types.FileBarAction;
pub const StartupAction = types.StartupAction;

// Re-export renderer
pub const Renderer = renderer.Renderer;

// Re-export state
pub const EditorUI = state.EditorUI;

// Re-export widget functions
pub const drawButton = widgets.drawButton;
pub const drawGreenButton = widgets.drawGreenButton;
pub const drawSlider = widgets.drawSlider;
pub const drawSliderNoValue = widgets.drawSliderNoValue;
pub const drawSignedSlider = widgets.drawSignedSlider;
pub const drawEnumDropdown = widgets.drawEnumDropdown;
pub const drawBoolDropdown = widgets.drawBoolDropdown;
pub const drawDropdownPopup = widgets.drawDropdownPopup;
pub const DropdownFieldId = types.DropdownFieldId;
pub const drawToggle = widgets.drawToggle;
pub const drawTextBox = widgets.drawTextBox;
pub const drawScrollbar = widgets.drawScrollbar;
pub const lerpColor = widgets.lerpColor;
pub const lightenColor = widgets.lightenColor;

// Re-export drawing functions
pub const drawWaveContextMenu = drawing.drawWaveContextMenu;
pub const drawWaveEditor = drawing.drawWaveEditor;
