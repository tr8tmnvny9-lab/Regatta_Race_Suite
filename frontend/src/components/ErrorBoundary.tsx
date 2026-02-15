import { Component, ErrorInfo, ReactNode } from "react";

interface Props {
    children: ReactNode;
}

interface State {
    hasError: boolean;
    error: Error | null;
}

class ErrorBoundary extends Component<Props, State> {
    public state: State = {
        hasError: false,
        error: null
    };

    public static getDerivedStateFromError(error: Error): State {
        return { hasError: true, error };
    }

    public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
        console.error("Uncaught error:", error, errorInfo);
    }

    public render() {
        if (this.state.hasError) {
            return (
                <div className="p-8 bg-black/80 text-white rounded-3xl border border-accent-red/50 backdrop-blur-3xl m-10">
                    <h2 className="text-2xl font-black uppercase text-accent-red mb-4">A component has crashed</h2>
                    <pre className="text-xs font-mono bg-black p-4 rounded-xl overflow-auto max-h-[400px]">
                        {this.state.error?.stack}
                    </pre>
                    <button
                        onClick={() => window.location.reload()}
                        className="mt-6 px-6 py-3 bg-accent-blue text-white rounded-xl font-bold uppercase tracking-widest text-[10px]"
                    >
                        Reload Application
                    </button>
                </div>
            );
        }

        return this.props.children;
    }
}

export default ErrorBoundary;
