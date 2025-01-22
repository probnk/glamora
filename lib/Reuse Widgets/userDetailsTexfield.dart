import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/UserDetailsProvider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class UserDetailsTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final String inputType;
  final Function(String) onChange;
  final FormFieldValidator<String>? validator;
  final bool isDarkMode;

  const UserDetailsTextField({
    Key? key,
    required this.label,
    required this.controller,
    required this.hintText,
    required this.inputType,
    this.validator,
    required this.onChange, required this.isDarkMode,
  }) : super(key: key);

  @override
  _UserDetailsTextFieldState createState() => _UserDetailsTextFieldState();
}

class _UserDetailsTextFieldState extends State<UserDetailsTextField> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 3),
      child: TextFormField(
        autofocus: true,
        cursorColor: widget.isDarkMode ? white : grayBlack,
        controller: widget.controller,
        onChanged: widget.onChange,
        decoration: InputDecoration(
          filled: true,
          fillColor: widget.isDarkMode ? lightGrayBlack : white,
          hintText: widget.hintText,
          hintStyle: GoogleFonts.montserrat(color: Colors.grey.shade400, fontSize: 14),
          label: smallFont(text: widget.label.toString(),color: widget.isDarkMode ? white : grayBlack),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.isDarkMode ? white : grayBlack, width: 3),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.red.shade900, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.red.shade900, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color:Colors.grey, width: 1.5),
          ),
        ),
        maxLength:widget.inputType == "text" ? 100 : widget.inputType == "zip" ? 5 : 11 ,
        keyboardType: widget.inputType == "text"
            ? TextInputType.text
            :  widget.inputType == "zip" ? TextInputType.number :TextInputType.phone,
        style: GoogleFonts.montserrat(color: grayBlack, fontSize: 14),
        validator: widget.validator,
      ),
    );
  }
}