# scripts/maintenance/enable_addon_in_blender.py
import bpy

def main():
    print("=== ENABLING BLENDER MCP ADDON ===")
    addon_name = "addon" # Name of the file (addon.py) or module
    
    try:
        # Check if already enabled
        enabled = addon_name in bpy.context.preferences.addons
        print(f"Addon '{addon_name}' enabled status before: {enabled}")
        
        if not enabled:
            bpy.ops.preferences.addon_enable(module=addon_name)
            print(f"Addon '{addon_name}' has been enabled.")
            
        # Save user preferences so it persists
        bpy.ops.wm.save_userpref()
        print("User preferences saved successfully.")
        
    except Exception as e:
        print(f"Error enabling addon: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
