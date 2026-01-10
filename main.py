import os
import json
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, simpledialog
from dataclasses import dataclass, field
from typing import List, Optional
import xml.etree.ElementTree as ET


# -----------------------------
# Data model
# -----------------------------

@dataclass
class Wave:
    name: str
    filepath: str


@dataclass
class Pad:
    name: str
    wave: Optional[Wave] = None
    volume: int = 100      # 0–127
    pan: int = 0           # -50..50 (we'll map to SPD-SX pan later)
    mute_group: int = 0
    trigger_mode: str = "SHOT"  # SHOT / LOOP / ALT


@dataclass
class Kit:
    name: str
    pads: List[Pad] = field(default_factory=list)


@dataclass
class Project:
    kits: List[Kit] = field(default_factory=list)
    waves: List[Wave] = field(default_factory=list)

    def add_kit(self, name: str) -> Kit:
        kit = Kit(name=name)
        for i in range(9):
            kit.pads.append(Pad(name=f"Pad {i+1}"))
        self.kits.append(kit)
        return kit

    def remove_kit(self, kit: Kit):
        self.kits.remove(kit)

    def add_wave(self, name: str, filepath: str) -> Wave:
        w = Wave(name=name, filepath=filepath)
        self.waves.append(w)
        return w

    def remove_wave(self, wave: Wave):
        # Remove from pads
        for kit in self.kits:
            for pad in kit.pads:
                if pad.wave is wave:
                    pad.wave = None
        self.waves.remove(wave)


# -----------------------------
# GUI application
# -----------------------------

class SPDStyleEditorApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("SPD-SX Style Kit Editor")
        self.geometry("1200x700")

        self.project = Project()
        self.current_kit: Optional[Kit] = None
        self.current_pad: Optional[Pad] = None
        self.copied_pad: Optional[Pad] = None

        self._create_widgets()
        self._create_menus()

        kit = self.project.add_kit("Kit 1")
        self.refresh_kit_list()
        self.refresh_wave_list()
        self.select_kit(0)

    # -------------------------
    # UI construction
    # -------------------------

    def _create_widgets(self):
        self.columnconfigure(0, weight=1, minsize=200)
        self.columnconfigure(1, weight=2)
        self.columnconfigure(2, weight=2)
        self.rowconfigure(0, weight=3)
        self.rowconfigure(1, weight=2)

        # Kits panel
        kits_frame = ttk.LabelFrame(self, text="Kits")
        kits_frame.grid(row=0, column=0, sticky="nsew", padx=5, pady=5)

        self.kit_listbox = tk.Listbox(kits_frame, exportselection=False)
        self.kit_listbox.pack(fill="both", expand=True)
        self.kit_listbox.bind("<<ListboxSelect>>", self.on_kit_selected)

        ttk.Button(kits_frame, text="Add Kit", command=self.add_kit).pack(fill="x")
        ttk.Button(kits_frame, text="Rename Kit", command=self.rename_kit).pack(fill="x")
        ttk.Button(kits_frame, text="Delete Kit", command=self.delete_kit).pack(fill="x")

        # Pads grid
        pads_frame = ttk.LabelFrame(self, text="Pads")
        pads_frame.grid(row=0, column=1, sticky="nsew", padx=5, pady=5)

        self.pad_buttons: List[tk.Button] = []
        for r in range(3):
            pads_frame.rowconfigure(r, weight=1)
            for c in range(3):
                pads_frame.columnconfigure(c, weight=1)
                idx = r * 3 + c
                btn = tk.Button(
                    pads_frame,
                    text=f"Pad {idx+1}",
                    command=lambda i=idx: self.on_pad_clicked(i)
                )
                btn.grid(row=r, column=c, sticky="nsew", padx=3, pady=3)
                self.pad_buttons.append(btn)

        # Pad details
        details_frame = ttk.LabelFrame(self, text="Pad details")
        details_frame.grid(row=0, column=2, sticky="nsew", padx=5, pady=5)
        details_frame.columnconfigure(1, weight=1)

        # Pad name
        ttk.Label(details_frame, text="Pad name").grid(row=0, column=0, sticky="w")
        self.pad_name_var = tk.StringVar()
        self.pad_name_entry = ttk.Entry(details_frame, textvariable=self.pad_name_var)
        self.pad_name_entry.grid(row=0, column=1, sticky="ew")
        self.pad_name_entry.bind("<FocusOut>", self.on_pad_name_changed)

        # Wave assignment
        ttk.Label(details_frame, text="Wave").grid(row=1, column=0, sticky="w")
        self.wave_combo_var = tk.StringVar()
        self.wave_combo = ttk.Combobox(details_frame, textvariable=self.wave_combo_var, state="readonly")
        self.wave_combo.grid(row=1, column=1, sticky="ew")
        self.wave_combo.bind("<<ComboboxSelected>>", self.on_wave_selected_for_pad)

        # Volume
        ttk.Label(details_frame, text="Volume").grid(row=2, column=0, sticky="w")
        self.volume_var = tk.IntVar()
        ttk.Scale(
            details_frame, from_=0, to=127, variable=self.volume_var,
            command=lambda v: self.update_pad_param("volume", int(float(v)))
        ).grid(row=2, column=1, sticky="ew")

        # Pan
        ttk.Label(details_frame, text="Pan").grid(row=3, column=0, sticky="w")
        self.pan_var = tk.IntVar()
        ttk.Scale(
            details_frame, from_=-50, to=50, variable=self.pan_var,
            command=lambda v: self.update_pad_param("pan", int(float(v)))
        ).grid(row=3, column=1, sticky="ew")

        # Mute group
        ttk.Label(details_frame, text="Mute group").grid(row=4, column=0, sticky="w")
        self.mute_group_var = tk.IntVar()
        ttk.Spinbox(
            details_frame, from_=0, to=8, textvariable=self.mute_group_var,
            command=lambda: self.update_pad_param("mute_group", self.mute_group_var.get())
        ).grid(row=4, column=1, sticky="ew")

        # Trigger mode
        ttk.Label(details_frame, text="Trigger mode").grid(row=5, column=0, sticky="w")
        self.trigger_mode_var = tk.StringVar()
        self.trigger_mode_combo = ttk.Combobox(
            details_frame, textvariable=self.trigger_mode_var,
            values=["SHOT", "LOOP", "ALT"], state="readonly"
        )
        self.trigger_mode_combo.grid(row=5, column=1, sticky="ew")
        self.trigger_mode_combo.bind(
            "<<ComboboxSelected>>",
            lambda e: self.update_pad_param("trigger_mode", self.trigger_mode_var.get())
        )

        # Copy / paste buttons
        copy_paste_frame = ttk.Frame(details_frame)
        copy_paste_frame.grid(row=6, column=0, columnspan=2, sticky="ew", pady=10)
        ttk.Button(copy_paste_frame, text="Copy pad", command=self.copy_pad).pack(
            side="left", expand=True, fill="x", padx=2
        )
        ttk.Button(copy_paste_frame, text="Paste pad", command=self.paste_pad).pack(
            side="left", expand=True, fill="x", padx=2
        )

        # Waves list
        waves_frame = ttk.LabelFrame(self, text="Waves")
        waves_frame.grid(row=1, column=0, columnspan=3, sticky="nsew", padx=5, pady=5)

        self.wave_listbox = tk.Listbox(waves_frame, exportselection=False)
        self.wave_listbox.pack(fill="both", expand=True)
        self.wave_listbox.bind("<<ListboxSelect>>", self.on_wave_selected_in_list)

        btn_frame = ttk.Frame(waves_frame)
        btn_frame.pack(fill="x")
        ttk.Button(btn_frame, text="Import wave", command=self.import_wave).pack(side="left", expand=True, fill="x")
        ttk.Button(btn_frame, text="Rename wave", command=self.rename_wave).pack(side="left", expand=True, fill="x")
        ttk.Button(btn_frame, text="Delete wave", command=self.delete_wave).pack(side="left", expand=True, fill="x")

    def _create_menus(self):
        menubar = tk.Menu(self)
        self.config(menu=menubar)

        file_menu = tk.Menu(menubar, tearoff=False)
        menubar.add_cascade(label="File", menu=file_menu)
        file_menu.add_command(label="New project", command=self.new_project)
        file_menu.add_command(label="Save project", command=self.save_project)
        file_menu.add_command(label="Load project", command=self.load_project)
        file_menu.add_separator()
        file_menu.add_command(label="Export kit (XML)", command=self.export_kit)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.quit)

    # -------------------------
    # Kit management
    # -------------------------

    def refresh_kit_list(self):
        self.kit_listbox.delete(0, tk.END)
        for kit in self.project.kits:
            self.kit_listbox.insert(tk.END, kit.name)

    def select_kit(self, index: int):
        if not (0 <= index < len(self.project.kits)):
            return
        self.kit_listbox.selection_clear(0, tk.END)
        self.kit_listbox.selection_set(index)
        self.current_kit = self.project.kits[index]
        self.current_pad = None
        self.update_pad_buttons()
        self.update_pad_details()

    def on_kit_selected(self, event):
        sel = self.kit_listbox.curselection()
        if sel:
            self.select_kit(sel[0])

    def add_kit(self):
        name = simpledialog.askstring("Add kit", "Kit name:")
        if not name:
            return
        kit = self.project.add_kit(name)
        self.refresh_kit_list()
        self.select_kit(self.project.kits.index(kit))

    def rename_kit(self):
        if not self.current_kit:
            return
        name = simpledialog.askstring("Rename kit", "New name:", initialvalue=self.current_kit.name)
        if not name:
            return
        self.current_kit.name = name
        self.refresh_kit_list()

    def delete_kit(self):
        if not self.current_kit:
            return
        if len(self.project.kits) == 1:
            messagebox.showwarning("Delete kit", "At least one kit is required.")
            return
        if not messagebox.askyesno("Delete kit", f"Delete kit '{self.current_kit.name}'?"):
            return
        idx = self.project.kits.index(self.current_kit)
        self.project.remove_kit(self.current_kit)
        self.refresh_kit_list()
        self.select_kit(max(0, idx - 1))

    # -------------------------
    # Pad management
    # -------------------------

    def update_pad_buttons(self):
        if not self.current_kit:
            return
        for i, pad in enumerate(self.current_kit.pads):
            label = pad.name
            if pad.wave:
                label += f"\n({pad.wave.name})"
            self.pad_buttons[i].config(text=label)

    def on_pad_clicked(self, index: int):
        if not self.current_kit:
            return
        self.current_pad = self.current_kit.pads[index]
        self.update_pad_details()

    def update_pad_details(self):
        if not self.current_pad:
            self.pad_name_var.set("")
            self.wave_combo["values"] = []
            self.wave_combo_var.set("")
            self.volume_var.set(100)
            self.pan_var.set(0)
            self.mute_group_var.set(0)
            self.trigger_mode_var.set("SHOT")
            return

        pad = self.current_pad
        self.pad_name_var.set(pad.name)

        wave_names = ["<None>"] + [w.name for w in self.project.waves]
        self.wave_combo["values"] = wave_names
        if pad.wave:
            self.wave_combo_var.set(pad.wave.name)
        else:
            self.wave_combo_var.set("<None>")

        self.volume_var.set(pad.volume)
        self.pan_var.set(pad.pan)
        self.mute_group_var.set(pad.mute_group)
        self.trigger_mode_var.set(pad.trigger_mode)

    def on_pad_name_changed(self, event):
        if not self.current_pad:
            return
        name = self.pad_name_var.get().strip()
        if name:
            self.current_pad.name = name
            self.update_pad_buttons()

    def update_pad_param(self, param: str, value):
        if not self.current_pad:
            return
        setattr(self.current_pad, param, value)
        self.update_pad_buttons()

    def on_wave_selected_for_pad(self, event):
        if not self.current_pad:
            return
        choice = self.wave_combo_var.get()
        if choice == "<None>":
            self.current_pad.wave = None
        else:
            w = next((x for x in self.project.waves if x.name == choice), None)
            self.current_pad.wave = w
        self.update_pad_buttons()

    # -------------------------
    # Pad copy / paste
    # -------------------------

    def copy_pad(self):
        if not self.current_pad:
            return
        p = self.current_pad
        self.copied_pad = Pad(
            name=p.name,
            wave=p.wave,
            volume=p.volume,
            pan=p.pan,
            mute_group=p.mute_group,
            trigger_mode=p.trigger_mode
        )
        messagebox.showinfo("Pad copied", f"Copied '{p.name}'")

    def paste_pad(self):
        if not self.current_pad or not self.copied_pad:
            return
        src = self.copied_pad
        dest = self.current_pad
        # Keep pad name; copy the rest
        dest.wave = src.wave
        dest.volume = src.volume
        dest.pan = src.pan
        dest.mute_group = src.mute_group
        dest.trigger_mode = src.trigger_mode
        self.update_pad_buttons()
        self.update_pad_details()
        messagebox.showinfo("Pad pasted", f"Pasted settings to '{dest.name}'")

    # -------------------------
    # Wave management
    # -------------------------

    def refresh_wave_list(self):
        self.wave_listbox.delete(0, tk.END)
        for w in self.project.waves:
            self.wave_listbox.insert(tk.END, w.name)

    def import_wave(self):
        path = filedialog.askopenfilename(
            title="Import wave",
            filetypes=[("WAV files", "*.wav"), ("All files", "*.*")]
        )
        if not path:
            return
        base = os.path.splitext(os.path.basename(path))[0]
        existing = {w.name for w in self.project.waves}
        name = base
        cnt = 1
        while name in existing:
            name = f"{base}_{cnt}"
            cnt += 1
        w = self.project.add_wave(name, path)
        self.refresh_wave_list()

    def get_selected_wave(self) -> Optional[Wave]:
        sel = self.wave_listbox.curselection()
        if not sel:
            return None
        return self.project.waves[sel[0]]

    def on_wave_selected_in_list(self, event):
        w = self.get_selected_wave()
        if w and self.current_pad:
            self.current_pad.wave = w
            self.update_pad_buttons()
            self.update_pad_details()

    def rename_wave(self):
        w = self.get_selected_wave()
        if not w:
            return
        new_name = simpledialog.askstring("Rename wave", "New name:", initialvalue=w.name)
        if not new_name:
            return
        if any(x.name == new_name for x in self.project.waves if x is not w):
            messagebox.showerror("Rename wave", "Name already in use.")
            return
        w.name = new_name
        self.refresh_wave_list()
        self.update_pad_buttons()
        self.update_pad_details()

    def delete_wave(self):
        w = self.get_selected_wave()
        if not w:
            return
        if not messagebox.askyesno("Delete wave", f"Delete wave '{w.name}'?"):
            return
        self.project.remove_wave(w)
        self.refresh_wave_list()
        self.update_pad_buttons()
        self.update_pad_details()

    # -------------------------
    # Project save/load (JSON, simple)
    # -------------------------

    def new_project(self):
        if not messagebox.askyesno("New project", "Discard current project?"):
            return
        self.project = Project()
        self.project.add_kit("Kit 1")
        self.refresh_kit_list()
        self.refresh_wave_list()
        self.select_kit(0)

    def save_project(self):
        path = filedialog.asksaveasfilename(
            title="Save project",
            defaultextension=".json",
            filetypes=[("JSON files", "*.json")]
        )
        if not path:
            return

        def wave_to_dict(w: Wave):
            return {"name": w.name, "filepath": w.filepath}

        def pad_to_dict(p: Pad):
            return {
                "name": p.name,
                "wave": p.wave.name if p.wave else None,
                "volume": p.volume,
                "pan": p.pan,
                "mute_group": p.mute_group,
                "trigger_mode": p.trigger_mode,
            }

        def kit_to_dict(k: Kit):
            return {
                "name": k.name,
                "pads": [pad_to_dict(p) for p in k.pads]
            }

        data = {
            "waves": [wave_to_dict(w) for w in self.project.waves],
            "kits": [kit_to_dict(k) for k in self.project.kits]
        }

        with open(path, "w") as f:
            json.dump(data, f, indent=4)

    def load_project(self):
        path = filedialog.askopenfilename(
            title="Load project",
            filetypes=[("JSON files", "*.json")]
        )
        if not path:
            return
        with open(path, "r") as f:
            data = json.load(f)

        self.project = Project()

        # Waves first
        wave_map = {}
        for w in data.get("waves", []):
            wave = self.project.add_wave(w["name"], w["filepath"])
            wave_map[wave.name] = wave

        # Kits and pads
        for k in data.get("kits", []):
            kit = self.project.add_kit(k["name"])
            kit.pads.clear()
            for p in k.get("pads", []):
                pad = Pad(
                    name=p["name"],
                    wave=wave_map.get(p["wave"]) if p["wave"] else None,
                    volume=p["volume"],
                    pan=p["pan"],
                    mute_group=p["mute_group"],
                    trigger_mode=p["trigger_mode"],
                )
                kit.pads.append(pad)

        self.refresh_kit_list()
        self.refresh_wave_list()
        self.select_kit(0)

    # -------------------------
    # SPD-SX style XML export
    # -------------------------

    def export_kit(self):
        if not self.current_kit:
            return

        export_dir = filedialog.askdirectory(title="Select export folder")
        if not export_dir:
            return

        kit_dir = os.path.join(export_dir, self.current_kit.name.replace(" ", "_"))
        os.makedirs(kit_dir, exist_ok=True)

        root = self.build_kit_xml(self.current_kit)

        xml_path = os.path.join(kit_dir, "kit.xml")
        tree = ET.ElementTree(root)
        tree.write(xml_path, encoding="utf-8", xml_declaration=True)

        # Also export used waves (optional but practical)
        waves_dir = os.path.join(kit_dir, "waves")
        os.makedirs(waves_dir, exist_ok=True)
        used_waves = {p.wave for p in self.current_kit.pads if p.wave}
        for w in used_waves:
            if not os.path.isfile(w.filepath):
                continue
            dest = os.path.join(waves_dir, os.path.basename(w.filepath))
            try:
                with open(w.filepath, "rb") as src, open(dest, "wb") as dst:
                    dst.write(src.read())
            except Exception as e:
                print("Error copying wave:", e)

        messagebox.showinfo("Export complete", f"Kit exported to:\n{xml_path}")

    def build_kit_xml(self, kit: Kit) -> ET.Element:
        root = ET.Element("KitPrm")

        # Global kit params (simplified defaults)
        ET.SubElement(root, "Level").text = "100"
        ET.SubElement(root, "Tempo").text = "1200"  # 120.0 BPM

        # Name bytes -> Nm0..Nm7
        name_bytes = kit.name.encode("ascii", errors="ignore")
        max_name_chars = 8
        for i in range(max_name_chars):
            val = name_bytes[i] if i < len(name_bytes) else 0
            ET.SubElement(root, f"Nm{i}").text = str(val)

        # Sub-name bytes -> SubNm0..SubNm15
        sub = "Electric Shock"  # or any label; can be made editable later
        sub_bytes = sub.encode("ascii", errors="ignore")
        max_sub = 16
        for i in range(max_sub):
            val = sub_bytes[i] if i < len(sub_bytes) else 0
            ET.SubElement(root, f"SubNm{i}").text = str(val)

        # FX / link defaults similar to your example
        ET.SubElement(root, "Fx2Asgn").text = "0"
        ET.SubElement(root, "LinkPad0").text = "-1"
        ET.SubElement(root, "LinkPad1").text = "-1"

        ET.SubElement(root, "Fx1Sw").text = "1"
        ET.SubElement(root, "Fx1Type").text = "19"
        fx1_defaults = [4, 30, 0, 1, 2, 10, 80, 100, 50] + [0] * 11
        for i, v in enumerate(fx1_defaults):
            ET.SubElement(root, f"Fx1Prm{i}").text = str(v)

        ET.SubElement(root, "Fx2Sw").text = "1"
        ET.SubElement(root, "Fx2Type").text = "15"
        fx2_defaults = [0, 50, 50, 50, 50, 100] + [0] * 14
        for i, v in enumerate(fx2_defaults):
            ET.SubElement(root, f"Fx2Prm{i}").text = str(v)

        # Map waves to integer IDs for <Wv>
        used_waves: List[Wave] = []
        wave_id = {}
        for p in kit.pads:
            if p.wave and p.wave not in used_waves:
                wave_id[p.wave] = len(used_waves)
                used_waves.append(p.wave)

        base_note = 60  # like your example

        for idx, pad in enumerate(kit.pads):
            pad_elem = ET.SubElement(root, "PadPrm")

            # Wv index or -1
            if pad.wave and pad.wave in wave_id:
                wv = wave_id[pad.wave]
            else:
                wv = -1
            ET.SubElement(pad_elem, "Wv").text = str(wv)

            # WvLevel from pad.volume
            ET.SubElement(pad_elem, "WvLevel").text = str(pad.volume)

            # Pan: map -50..50 -> 0..30 with 15 center (SPD-ish)
            pan_val = int((pad.pan + 50) * 30 / 100)
            pan_val = max(0, min(30, pan_val))
            ET.SubElement(pad_elem, "WvPan").text = str(pan_val)

            # Trigger / loop mapping
            if pad.trigger_mode == "SHOT":
                play_mode = 0
                loop_flag = 0
                trig_type = 0
            else:  # LOOP or ALT
                play_mode = 2
                loop_flag = 1
                trig_type = 1

            ET.SubElement(pad_elem, "PlayMode").text = str(play_mode)
            ET.SubElement(pad_elem, "OutAsgn").text = "0"
            ET.SubElement(pad_elem, "MuteGrp").text = str(pad.mute_group)
            ET.SubElement(pad_elem, "TempoSync").text = "0"
            ET.SubElement(pad_elem, "PadMidiCh").text = "-1"
            ET.SubElement(pad_elem, "NoteNum").text = str(base_note + idx)
            ET.SubElement(pad_elem, "MidiCtrl").text = "0"
            ET.SubElement(pad_elem, "Loop").text = str(loop_flag)
            ET.SubElement(pad_elem, "TrigType").text = str(trig_type)
            ET.SubElement(pad_elem, "GateTime").text = "-1"
            ET.SubElement(pad_elem, "Dynamics").text = "1"
            ET.SubElement(pad_elem, "VoiceAsgn").text = "1"
            ET.SubElement(pad_elem, "Reverse").text = "0"

            ET.SubElement(pad_elem, "SubWv").text = "-1"
            ET.SubElement(pad_elem, "SubWvLevel").text = "100"
            ET.SubElement(pad_elem, "SubWvPan").text = "15"

        return root


if __name__ == "__main__":
    app = SPDStyleEditorApp()
    app.mainloop()

