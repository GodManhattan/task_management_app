import 'package:equatable/equatable.dart';

/// Base state class for all BLoC states in the application
abstract class BaseState extends Equatable {
  const BaseState();

  @override
  List<Object?> get props => [];
}

/// Represents the initial state of a feature
class InitialState extends BaseState {
  const InitialState();
}

/// Represents a loading state when an operation is in progress
class LoadingState extends BaseState {
  const LoadingState();
}

/// Represents a successful operation with optional data
class SuccessState<T> extends BaseState {
  final T data;

  const SuccessState(this.data);

  @override
  List<Object?> get props => [data];
}

/// Represents an error state with error message
class ErrorState extends BaseState {
  final String message;
  final Object? error;

  const ErrorState(this.message, {this.error});

  @override
  List<Object?> get props => [message, error];
}
