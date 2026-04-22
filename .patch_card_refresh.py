import sys
BANG = chr(33)  # ! - avoids bash history expansion in heredocs
path = '/sessions/relaxed-jolly-pasteur/mnt/HopeTSIT_FINAL_FIXED/HopeTSIT_FINAL/frontend/lib/views/notifications/notification_sitter_application_card_view_screen.dart'
with open(path, 'r') as f:
    c = f.read()

old_accept = (
"                    onAccept: () async {\n"
"                      final result = await _controller.acceptApplication(\n"
"                        booking.id,\n"
"                      );\n"
"                      if (" + BANG + "mounted) return;\n"
"\n"
"                      if (result['success'] == true) {\n"
"                        CustomSnackbar.showSuccess(\n"
"                          title: 'common_success'.tr,\n"
"                          message: 'sitter_application_accepted_success'.tr,\n"
"                        );\n"
"                        Get.back();\n"
"                      } else {\n"
"                        CustomSnackbar.showError(\n"
"                          title: 'common_error'.tr,\n"
"                          message:\n"
"                              result['message'] as String? ??\n"
"                              'sitter_application_accept_failed'.tr,\n"
"                        );\n"
"                      }\n"
"                    },"
)

new_accept = (
"                    onAccept: () async {\n"
"                      final result = await _controller.acceptApplication(\n"
"                        booking.id,\n"
"                      );\n"
"                      if (" + BANG + "mounted) return;\n"
"\n"
"                      if (result['success'] == true) {\n"
"                        CustomSnackbar.showSuccess(\n"
"                          title: 'common_success'.tr,\n"
"                          message: 'sitter_application_accepted_success'.tr,\n"
"                        );\n"
"                        Get.back();\n"
"                      } else {\n"
"                        // Session v16.3d - refresh bookings so a stale\n"
"                        // 'pending' badge updates after backend 409.\n"
"                        await _controller.loadBookings();\n"
"                        CustomSnackbar.showError(\n"
"                          title: 'common_error'.tr,\n"
"                          message:\n"
"                              result['message'] as String? ??\n"
"                              'sitter_application_accept_failed'.tr,\n"
"                        );\n"
"                      }\n"
"                    },"
)

if old_accept not in c:
    sys.exit('onAccept pattern not found')
c = c.replace(old_accept, new_accept, 1)

old_reject = (
"                    onReject: () async {\n"
"                      final result = await _controller.rejectApplication(\n"
"                        booking.id,\n"
"                      );\n"
"                      if (" + BANG + "mounted) return;\n"
"\n"
"                      if (result['success'] == true) {\n"
"                        CustomSnackbar.showSuccess(\n"
"                          title: 'common_success'.tr,\n"
"                          message: 'sitter_application_rejected_success'.tr,\n"
"                        );\n"
"                        Get.back();\n"
"                      } else {\n"
"                        CustomSnackbar.showError(\n"
"                          title: 'common_error'.tr,\n"
"                          message:\n"
"                              result['message'] as String? ??\n"
"                              'sitter_application_reject_failed'.tr,\n"
"                        );\n"
"                      }\n"
"                    },"
)

new_reject = (
"                    onReject: () async {\n"
"                      final result = await _controller.rejectApplication(\n"
"                        booking.id,\n"
"                      );\n"
"                      if (" + BANG + "mounted) return;\n"
"\n"
"                      if (result['success'] == true) {\n"
"                        CustomSnackbar.showSuccess(\n"
"                          title: 'common_success'.tr,\n"
"                          message: 'sitter_application_rejected_success'.tr,\n"
"                        );\n"
"                        Get.back();\n"
"                      } else {\n"
"                        await _controller.loadBookings();\n"
"                        CustomSnackbar.showError(\n"
"                          title: 'common_error'.tr,\n"
"                          message:\n"
"                              result['message'] as String? ??\n"
"                              'sitter_application_reject_failed'.tr,\n"
"                        );\n"
"                      }\n"
"                    },"
)

if old_reject not in c:
    sys.exit('onReject pattern not found')
c = c.replace(old_reject, new_reject, 1)

with open(path, 'w') as f:
    f.write(c)
print(f'OK ({len(c)} bytes)')
