import 'package:flutter/material.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/robot/robot_painter.dart';
import '../../core/constants/service_data.dart';
import '../../widgets/phone_mockup/mock_screens.dart';
import 'sections/service_detail_section.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = ServiceData.services;

    return PageShell(
      sections: [
        // Food
        ServiceDetailSection(
          service: services[0],
          isDark: false,
          reversed: false,
          robotProp: RobotProp.tray,
          mockupScreens: const [MockFoodScreen(), MockHomeScreen()],
        ),
        // Market
        ServiceDetailSection(
          service: services[1],
          isDark: true,
          reversed: true,
          robotProp: RobotProp.shoppingBag,
          mockupScreens: const [MockHomeScreen(), MockFoodScreen()],
        ),
        // Taxi
        ServiceDetailSection(
          service: services[2],
          isDark: false,
          reversed: false,
          robotProp: RobotProp.taxiCap,
          mockupScreens: const [MockTaxiScreen(), MockHomeScreen()],
        ),
        // Courier
        ServiceDetailSection(
          service: services[3],
          isDark: true,
          reversed: true,
          robotProp: RobotProp.scooter,
          mockupScreens: const [MockHomeScreen(), MockTaxiScreen()],
        ),
        // Emlak
        ServiceDetailSection(
          service: services[4],
          isDark: false,
          reversed: false,
          robotProp: RobotProp.key,
          mockupScreens: const [MockEmlakScreen(), MockHomeScreen()],
        ),
        // Car Sales
        ServiceDetailSection(
          service: services[5],
          isDark: true,
          reversed: true,
          robotProp: RobotProp.none,
          mockupScreens: const [MockCarScreen(), MockHomeScreen()],
        ),
        // Car Rental
        ServiceDetailSection(
          service: services[6],
          isDark: false,
          reversed: false,
          robotProp: RobotProp.key,
          mockupScreens: const [MockHomeScreen(), MockCarScreen()],
        ),
        // Jobs
        ServiceDetailSection(
          service: services[7],
          isDark: true,
          reversed: true,
          robotProp: RobotProp.briefcase,
          mockupScreens: const [MockHomeScreen(), MockFoodScreen()],
        ),
      ],
    );
  }
}
