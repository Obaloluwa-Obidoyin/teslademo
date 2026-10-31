//text

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class tText extends StatelessWidget {
  const tText({
    super.key,
    required this.data,
    this.fontWeight = FontWeight.w500,
    this.fontSize = 20,
    this.color = Colors.white,
  });
  final String data;
  final FontWeight fontWeight;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: GoogleFonts.inter(
        fontWeight: fontWeight,
        fontSize: fontSize,
        color: color,
      ),
    );
  }
}

class tSvg extends StatelessWidget {
  const tSvg({
    super.key,
    required this.data,
    this.height = 25,
    this.width = 25,
    this.color,
  });
  final String data;
  final double height;
  final double width;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      height: height,
      width: width,
      data,
      color: color,
      fit: BoxFit.contain,
    );
  }
}
