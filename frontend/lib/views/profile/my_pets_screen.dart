import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/my_pets_controller.dart';
import 'package:hopetsit/controllers/user_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/pet_model.dart';
import 'package:hopetsit/repositories/auth_repository.dart' show AuthRepository;
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/views/pet_owner/pet_profile/create_pet_profile_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/profile/edit_pet_screen.dart';

class MyPetsScreen extends StatelessWidget {
  const MyPetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final MyPetsController controller = Get.put(MyPetsController());
    final AuthController authController = Get.put(
      AuthController(AuthRepository(ApiClient()), GetStorage()),
    );
    final UserController userController = Get.put(
      UserController(UserRepository(ApiClient())),
    );

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'my_pets_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextButton(
              onPressed: () => Get.to(
                () => CreatePetProfileScreen(
                  userType: authController.userRole.value ?? '',
                  serviceType: userController.profile.value?.service.isNotEmpty == true
                      ? userController.profile.value!.service.first
                      : '',
                ),
              ),
              child: PoppinsText(
                text: 'my_pets_add_pet'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value.isNotEmpty &&
              controller.pets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PoppinsText(
                    text: 'my_pets_error_loading'.tr,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.errorColor,
                  ),
                  SizedBox(height: 8.h),
                  ElevatedButton(
                    onPressed: () => controller.refreshPets(),
                    child: Text('my_pets_retry'.tr),
                  ),
                ],
              ),
            );
          }

          if (controller.pets.isEmpty) {
            return Center(
              child: PoppinsText(
                text: 'my_pets_empty'.tr,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.greyColor,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => controller.refreshPets(),
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              itemCount: controller.pets.length,
              itemBuilder: (context, index) {
                final pet = controller.pets[index];
                return _buildPetCard(context, pet);
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPetCard(BuildContext context, PetModel pet) {
    final imageUrl = pet.avatar.url.isNotEmpty ? pet.avatar.url : null;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Section with Pet Image
          Container(
            height: 140.h,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
              ),
              color: AppColors.lightGreyColor,
            ),
            child: Stack(
              children: [
                // Pet Image
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                    topRight: Radius.circular(16.r),
                  ),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: 200.h,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(
                            color: AppColors.lightGreyColor,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.lightGreyColor,
                            child: Image.asset(
                              AppImages.placeholderImage,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.lightGreyColor,
                          child: Center(
                            child: Icon(
                              Icons.pets,
                              size: 40.sp,
                              color: AppColors.greyColor,
                            ),
                          ),
                        ),
                ),
                // Gradient overlay for better text readability
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16.r),
                        topRight: Radius.circular(16.r),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),
                // Pet Name and Category Badge
                Positioned(
                  bottom: 12.h,
                  left: 16.w,
                  right: 16.w,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PoppinsText(
                              text: pet.petName,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.whiteColor,
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor,
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.pets,
                                        size: 12.sp,
                                        color: AppColors.whiteColor,
                                      ),
                                      SizedBox(width: 4.w),
                                      InterText(
                                        text: pet.category,
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.whiteColor,
                                      ),
                                    ],
                                  ),
                                ),
                                if (pet.age.isNotEmpty) ...[
                                  SizedBox(width: 6.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 3.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.whiteColor.withOpacity(
                                        0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(16.r),
                                    ),
                                    child: InterText(
                                      text: pet.age,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.whiteColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Edit Button
                      GestureDetector(
                        onTap: () async {
                          final result = await Get.to(
                            () => EditPetScreen(petId: pet.id, petData: pet),
                          );
                          // Refresh pets list after editing if update was successful
                          if (result == true) {
                            final myPetsController =
                                Get.find<MyPetsController>();
                            await myPetsController.refreshPets();
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.whiteColor.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit,
                            size: 18.sp,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content Section
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breed and Physical Details in one row
                Row(
                  children: [
                    if (pet.breed.isNotEmpty) ...[
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.category,
                              size: 14.sp,
                              color: AppColors.primaryColor,
                            ),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: InterText(
                                text: pet.breed,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.greyText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (pet.weight.isNotEmpty) ...[
                      if (pet.breed.isNotEmpty) SizedBox(width: 12.w),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.monitor_weight,
                              size: 14.sp,
                              color: AppColors.primaryColor,
                            ),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: InterText(
                                text: '${pet.weight} kg',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.blackColor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (pet.height.isNotEmpty) ...[
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.height,
                              size: 14.sp,
                              color: AppColors.primaryColor,
                            ),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: InterText(
                                text: '${pet.height} cm',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.blackColor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 12.h),

                // Bio Section (compact)
                if (pet.bio.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: InterText(
                      text: pet.bio,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.blackColor,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],

                // Physical Details Section (compact horizontal)
                if (pet.colour.isNotEmpty || pet.profileView.isNotEmpty) ...[
                  Row(
                    children: [
                      if (pet.colour.isNotEmpty) ...[
                        Expanded(
                          child: _buildCompactInfoItem(
                            Icons.palette,
                            'my_pets_color_label'.tr,
                            pet.colour,
                          ),
                        ),
                      ],
                      if (pet.profileView.isNotEmpty) ...[
                        if (pet.colour.isNotEmpty) SizedBox(width: 8.w),
                        Expanded(
                          child: _buildCompactInfoItem(
                            Icons.visibility,
                            'my_pets_profile_label'.tr,
                            pet.profileView,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 12.h),
                ],

                // Medical & Identification Section (compact)
                if (pet.passportNumber.isNotEmpty ||
                    pet.chipNumber.isNotEmpty ||
                    pet.medicationAllergies.isNotEmpty ||
                    pet.vaccinations.isNotEmpty) ...[
                  Row(
                    children: [
                      if (pet.passportNumber.isNotEmpty) ...[
                        Expanded(
                          child: _buildCompactInfoItem(
                            Icons.article,
                            'my_pets_passport_label'.tr,
                            pet.passportNumber,
                          ),
                        ),
                      ],
                      if (pet.chipNumber.isNotEmpty) ...[
                        if (pet.passportNumber.isNotEmpty) SizedBox(width: 8.w),
                        Expanded(
                          child: _buildCompactInfoItem(
                            Icons.qr_code,
                            'my_pets_chip_label'.tr,
                            pet.chipNumber,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (pet.medicationAllergies.isNotEmpty) ...[
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppColors.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppColors.errorColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16.sp,
                            color: AppColors.errorColor,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InterText(
                                  text: 'my_pets_allergies_label'.tr,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.errorColor,
                                ),
                                SizedBox(height: 2.h),
                                InterText(
                                  text: pet.medicationAllergies,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.blackColor,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (pet.vaccinations.isNotEmpty) ...[
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: pet.vaccinations.map((vaccination) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: AppColors.primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 12.sp,
                                color: AppColors.primaryColor,
                              ),
                              SizedBox(width: 4.w),
                              InterText(
                                text: vaccination,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryColor,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoItem(IconData icon, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.lightGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: AppColors.primaryColor),
          SizedBox(width: 6.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InterText(
                  text: label,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.greyText,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: value,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blackColor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
