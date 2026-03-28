abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const profile = '/profile';

  static const students = '/students';
  static const studentsNew = '/students/new';

  static String studentDetailPath(String studentId) => '/students/$studentId';

  static String studentEditPath(String studentId) =>
      '/students/$studentId/edit';

  static String studentGradesPath(String studentId) =>
      '/students/$studentId/grades';

  static String studentGradeNewPath(String studentId) =>
      '/students/$studentId/grades/new';

  static String studentGradeEditPath(String studentId, String gradeId) =>
      '/students/$studentId/grades/$gradeId/edit';

  static const classes = '/classes';
  static const classesNew = '/classes/new';

  static String classDetailPath(String classId) => '/classes/$classId';

  static String classEditPath(String classId) => '/classes/$classId/edit';

  static String classRecordAbsencesPath(String classId) =>
      '/classes/$classId/record-absences';

  static String classSubjectGradesPath(String classId, String classSubjectId) =>
      '/classes/$classId/subject-grades/$classSubjectId';

  static String classSubjectFinalGradesHubPath(
    String classId,
    String classSubjectId,
  ) => '/classes/$classId/subject-grades/$classSubjectId/final-grades';

  static String classSubjectFinalGradeFormPath(
    String classId,
    String classSubjectId,
    String studentId,
  ) =>
      '/classes/$classId/subject-grades/$classSubjectId/final-grades/students/$studentId/final-grade';

  static String studentFinalGradeFormPath(
    String studentId,
    String classSubjectId,
  ) => '/students/$studentId/final-grades/$classSubjectId';

  static String studentAbsencesPath(String studentId) =>
      '/students/$studentId/absences';

  static String studentAbsenceNewPath(String studentId) =>
      '/students/$studentId/absences/new';

  static String studentAbsenceEditPath(String studentId, String absenceId) =>
      '/students/$studentId/absences/$absenceId/edit';

  static const subjects = '/subjects';
  static const subjectsNew = '/subjects/new';

  static String subjectDetailPath(String subjectId) => '/subjects/$subjectId';

  static String subjectEditPath(String subjectId) =>
      '/subjects/$subjectId/edit';
}
