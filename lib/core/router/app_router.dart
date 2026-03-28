import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_vault/core/providers/supabase_provider.dart';
import 'package:teacher_vault/core/router/app_routes.dart';
import 'package:teacher_vault/core/router/go_router_refresh.dart';
import 'package:teacher_vault/features/auth/presentation/screens/login_screen.dart';
import 'package:teacher_vault/features/auth/presentation/screens/register_screen.dart';
import 'package:teacher_vault/features/home/presentation/screens/home_screen.dart';
import 'package:teacher_vault/features/students/presentation/screens/student_detail_screen.dart';
import 'package:teacher_vault/features/students/presentation/screens/student_form_screen.dart';
import 'package:teacher_vault/features/classes/presentation/screens/class_detail_screen.dart';
import 'package:teacher_vault/features/classes/presentation/screens/class_form_screen.dart';
import 'package:teacher_vault/features/classes/presentation/screens/classes_list_screen.dart';
import 'package:teacher_vault/features/students/presentation/screens/students_list_screen.dart';
import 'package:teacher_vault/features/subjects/presentation/screens/subject_detail_screen.dart';
import 'package:teacher_vault/features/subjects/presentation/screens/subject_form_screen.dart';
import 'package:teacher_vault/features/subjects/presentation/screens/subjects_list_screen.dart';
import 'package:teacher_vault/features/teacher_profile/presentation/screens/profile_screen.dart';
import 'package:teacher_vault/features/grades/presentation/screens/class_subject_grades_screen.dart';
import 'package:teacher_vault/features/grades/presentation/screens/grade_form_screen.dart';
import 'package:teacher_vault/features/grades/presentation/screens/student_grades_screen.dart';
import 'package:teacher_vault/features/final_grades/presentation/screens/class_subject_final_grades_list_screen.dart';
import 'package:teacher_vault/features/final_grades/presentation/screens/final_grade_form_screen.dart';
import 'package:teacher_vault/features/absences/presentation/screens/absence_form_screen.dart';
import 'package:teacher_vault/features/absences/presentation/screens/student_absences_screen.dart';
import 'package:teacher_vault/features/absences/presentation/screens/class_record_absences_screen.dart';
import 'package:teacher_vault/core/shell/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseProvider);
  final refresh = GoRouterRefreshStream(client.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = client.auth.currentSession != null;
      final atAuth =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;
      if (!loggedIn && !atAuth) return AppRoutes.login;
      if (loggedIn && atAuth) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.students,
            builder: (context, state) => const StudentsListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const StudentFormScreen(),
              ),
              GoRoute(
                path: ':studentId',
                builder: (context, state) {
                  final id = state.pathParameters['studentId']!;
                  return StudentDetailScreen(studentId: id);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final id = state.pathParameters['studentId']!;
                      return StudentFormScreen(studentId: id);
                    },
                  ),
                  GoRoute(
                    path: 'grades',
                    builder: (context, state) {
                      final id = state.pathParameters['studentId']!;
                      return StudentGradesScreen(studentId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) {
                          final id = state.pathParameters['studentId']!;
                          return GradeFormScreen(studentId: id);
                        },
                      ),
                      GoRoute(
                        path: ':gradeId/edit',
                        builder: (context, state) {
                          final sid = state.pathParameters['studentId']!;
                          final gid = state.pathParameters['gradeId']!;
                          return GradeFormScreen(studentId: sid, gradeId: gid);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'final-grades/:classSubjectId',
                    builder: (context, state) {
                      final sid = state.pathParameters['studentId']!;
                      final csid = state.pathParameters['classSubjectId']!;
                      return FinalGradeFormScreen(
                        studentId: sid,
                        classSubjectId: csid,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'absences',
                    builder: (context, state) {
                      final id = state.pathParameters['studentId']!;
                      return StudentAbsencesScreen(studentId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) {
                          final id = state.pathParameters['studentId']!;
                          return AbsenceFormScreen(studentId: id);
                        },
                      ),
                      GoRoute(
                        path: ':absenceId/edit',
                        builder: (context, state) {
                          final sid = state.pathParameters['studentId']!;
                          final aid = state.pathParameters['absenceId']!;
                          return AbsenceFormScreen(
                            studentId: sid,
                            absenceId: aid,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.classes,
            builder: (context, state) => const ClassesListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const ClassFormScreen(),
              ),
              GoRoute(
                path: ':classId',
                builder: (context, state) {
                  final id = state.pathParameters['classId']!;
                  return ClassDetailScreen(classId: id);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final id = state.pathParameters['classId']!;
                      return ClassFormScreen(classId: id);
                    },
                  ),
                  GoRoute(
                    path: 'record-absences',
                    builder: (context, state) {
                      final id = state.pathParameters['classId']!;
                      return ClassRecordAbsencesScreen(classId: id);
                    },
                  ),
                  GoRoute(
                    path: 'subject-grades/:classSubjectId',
                    builder: (context, state) {
                      final cid = state.pathParameters['classId']!;
                      final csid = state.pathParameters['classSubjectId']!;
                      return ClassSubjectGradesScreen(
                        classId: cid,
                        classSubjectId: csid,
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'final-grades',
                        builder: (context, state) {
                          final cid = state.pathParameters['classId']!;
                          final csid = state.pathParameters['classSubjectId']!;
                          return ClassSubjectFinalGradesListScreen(
                            classId: cid,
                            classSubjectId: csid,
                          );
                        },
                        routes: [
                          GoRoute(
                            path: 'students/:studentId/final-grade',
                            builder: (context, state) {
                              final cid = state.pathParameters['classId']!;
                              final csid =
                                  state.pathParameters['classSubjectId']!;
                              final sid = state.pathParameters['studentId']!;
                              return FinalGradeFormScreen(
                                studentId: sid,
                                classSubjectId: csid,
                                classId: cid,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.subjects,
            builder: (context, state) => const SubjectsListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const SubjectFormScreen(),
              ),
              GoRoute(
                path: ':subjectId',
                builder: (context, state) {
                  final id = state.pathParameters['subjectId']!;
                  return SubjectDetailScreen(subjectId: id);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final id = state.pathParameters['subjectId']!;
                      return SubjectFormScreen(subjectId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
