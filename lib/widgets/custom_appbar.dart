import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../bloc/authentication/authentication_bloc.dart';
import '../bloc/authentication/authentication_state.dart';
import '../pages/recipe_generator.dart';
import '../pages/user_account_page.dart';
import '../pages/views/login_page.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.isHomePage,
    required this.isLoggedIn,
  });

  final bool isHomePage;
  final bool isLoggedIn;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title:  const Align(alignment: Alignment.centerLeft,
          child: Text('Nourish'),),
      leading:  IconButton(
        icon:  const FaIcon(
          FontAwesomeIcons.house,
          color: Colors.white,
        ),
        onPressed: isHomePage
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const RecipeGenerator(),
                  ),
                );
              },
      ),
      actions: [
        BlocBuilder<AuthenticationBloc, AuthenticationState>(
          builder: (context, state) {
            return Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (isLoggedIn) {
                      Navigator.of(context).pushNamed('/payWall');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                          const LoginPage(),
                        ),
                      );
                    }
                  },
                  icon: const FaIcon(
                    FontAwesomeIcons.gift,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (isLoggedIn) {
                      Navigator.of(context).pushNamed('/notes');
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                          const LoginPage(),
                        ),
                      );
                    }
                  },
                  icon: const FaIcon(
                    FontAwesomeIcons.pencil,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                         isLoggedIn ?  const UserAccountWidget()
                             : const LoginPage(),
                      ),
                    );
                  },
                  icon: isLoggedIn
                      ? const FaIcon(
                      FontAwesomeIcons.userCheck,
                      color: Colors.white,
                      )
                      : const FaIcon(
                          FontAwesomeIcons.userLock,
                          color: Colors.white,
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
